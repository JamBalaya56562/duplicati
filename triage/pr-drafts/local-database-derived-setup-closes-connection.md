Builds on #7366, and reuses the release it adds, moved into a shared helper. Open it after #7366 is merged, rebased on master.

## What happens

#7366 closes the connection when `LocalDatabase.CreateLocalDatabaseAsync(string path, ...)` fails to set up the base database. Two database classes do more setup after that, and have the same gap there:

- `LocalBackupDatabase.CreateAsync(string path, ...)` prepares the backup's commands, and only then sets `ShouldCloseConnection`.
- `LocalDeleteDatabase.CreateAsync(string path, ...)`, used by compact, delete and purge, prepares its register command.

When that setup throws, the caller never gets the database, and nothing closes the connection the base opened. The file stays open until the process exits.

The connection also holds its open transaction. Measured: a later write on the same database waits out the 10 s busy timeout each time, so the failed test run took about 1.5 minutes instead of about a second. On Windows, the database file cannot be deleted until the process exits.

The setup uses the progress token (`PrepareAsync(token)`), so an abort is one way to fail it. That abort window is narrow: aborting a backup through `Controller` at 2 ms steps after it started (25 attempts) did not hit it. A database missing a table that the setup prepares a command for fails it every time.

## The change

`ReleaseAfterFailedSetupAsync` (new, protected, in `LocalDatabase`) releases the commands, the reusable transaction and the connection. It is the release from #7366 moved out of `CreateLocalDatabaseAsync`, which now calls it. The two derived creators call it too when their own setup fails. It does not call the instance's own dispose, as a derived database may not be initialized at that point.

## Red to green

Two tests in `FailedOperationDatabaseTests` (from #7366). Each makes a backup, drops a table that only the derived setup prepares a command for, runs the operation through `Controller`, and checks that the database file is no longer open (an exclusive open on Windows, `/proc/self/fd` on Linux).

| Test | Table dropped | Before | After |
|---|---|---|---|
| Backup | `BlocklistHash` | **red**: still open (the run took about 1.5 minutes) | green (about 1 s) |
| Compact | `DuplicateBlock` | **red**: still open | green |

Measured on Windows and on Linux (ext4, WSL). Related tests pass (13: `FailedOperationDatabaseTests`, `AbortedBackupTests`, `PurgeTesting`, compact tests, the server lifecycle test and others).

## Not covered

The abort case could not be reproduced through `Controller` (see above). The tests reach the same failure by making the setup fail.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
