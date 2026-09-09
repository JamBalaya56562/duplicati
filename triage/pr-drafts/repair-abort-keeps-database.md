## What happens

`RepairHandler.RunAsync` first opens the local database and counts its remote volumes, to decide whether the database can be used. Any exception there was caught as "Failed to read local db", which leaves the count at -1. The repair then takes the recreate path: it renames the database to `.backup` and recreates it from the remote files.

An abort cancels that read with a `TaskCanceledException`, so aborting a repair right after it starts sends a healthy database down the same path. Measured by aborting a repair through `Controller` at 3 ms steps after it started (30 attempts, on master):

- 9 attempts logged `FailedToReadLocalDatabase` (`TaskCanceledException`) followed by `RenamingDatabase`.
- **On Linux (ext4, WSL)** the rename succeeded. The 200 KB database became `.backup`, a new 4 KB database was created in its place, and the 457 KB write-ahead log stayed behind under the original name, cut off from the database it belongs to.
- **On Windows** the rename failed with an `IOException` on the file that was still open. That hides the damage, but once #7366 closes the connection a failed open leaves behind, the rename will succeed there too.

## The change

When the progress token is cancelled, the exception from reading the database is passed on instead of being taken as an unreadable database. The repair ends as an aborted operation does elsewhere. Other errors (a corrupt or unreadable database) still lead to the recreate, as before.

## Red to green

`RepairHandlerTests.AbortedRepairDoesNotSetTheDatabaseAsideAsync` (new) runs `RepairHandler.RunAsync` in the state an abort leaves it in: the task control is terminated, so the progress token is cancelled. It checks that the database is not renamed and that the repair ends with an `OperationCanceledException`. It uses a database of its own, since on master a cancelled open leaves the file open (#7366), which would fail the teardown.

| | Before | After |
|---|---|---|
| The aborted repair sets the database aside | **red**: `Renaming existing db ...` | green |

Measured on Windows and on Linux (ext4, WSL). All of `RepairHandlerTests` pass (23).

The same abort through `Controller`, repeated with the timing above, logged no rename in 30 attempts after the change (9 before).

## Not covered

- A database that another operation holds a write lock on, as the busy timeout expires. Through `Controller`, `RestoreOptionsFromExistingDatabase` writes to the database before the repair starts, so the repair fails there with `database is locked` and never reaches this code. That was measured with a write transaction held from a second connection. It could only reach this code if the lock is taken in between, so it is left unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
