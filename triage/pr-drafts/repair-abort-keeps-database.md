## What happens

`RepairHandler.RunAsync` first opens the local database and counts its remote volumes, to decide whether the database can be used. Any exception there was caught as "Failed to read local db", which leaves the count at -1. The repair then takes the recreate path: it renames the database to `.backup-N` and recreates it from the remote files.

An abort cancels that read with a `TaskCanceledException`, so aborting a repair right after it starts sends a healthy database down the same path. Measured on Windows by aborting a repair through `Controller` 0 to 2.9 ms after it started, at 0.1 ms steps (60 attempts, on master):

- 56 attempts logged `FailedToReadLocalDatabase` (`TaskCanceledException`) followed by `RenamingDatabase`, and the database was set aside as `.backup-N`. The other 4, aborted at 0 and 0.1 ms, ended without an error and kept the database.
- Since #7366 closes the connection that a failed open leaves behind, the rename succeeds on Windows too. Before that, it failed there with an `IOException` on the file that was still open.

## The change

When the progress token is cancelled, the exception from reading the database is passed on instead of being taken as an unreadable database. The repair ends as an aborted operation does elsewhere. Other errors (a corrupt or unreadable database) still lead to the recreate, as before.

## Red to green

`RepairHandlerTests.AbortedRepairDoesNotSetTheDatabaseAsideAsync` (new) runs `RepairHandler.RunAsync` in the state an abort leaves it in: the task control is terminated, so the progress token is cancelled. It checks that the database is not renamed and that the repair ends with an `OperationCanceledException`. It uses a database of its own, as the teardown does not delete the `.backup` files a repair leaves, and with the shared name a file left by an earlier run failed the check on Linux.

| | Before | After |
|---|---|---|
| The aborted repair sets the database aside | **red**: `Renaming existing db ...` | green |

Measured on Windows and on Linux (ext4, WSL). All of `RepairHandlerTests` pass (23).

The same aborts through `Controller` set the database aside in none of the 60 attempts after the change (56 before).

## Not covered

- A database that another operation holds a write lock on, as the busy timeout expires. Through `Controller`, `RestoreOptionsFromExistingDatabase` writes to the database before the repair starts, so the repair fails there with `database is locked` and never reaches this code. That was measured with a write transaction held from a second connection. It could only reach this code if the lock is taken in between, so it is left unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
