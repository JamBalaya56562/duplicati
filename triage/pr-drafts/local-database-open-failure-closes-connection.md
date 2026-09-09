## What happens

`LocalDatabase.CreateLocalDatabaseAsync(string path, ...)` opens a connection and then sets up the database on it. When the setup throws, the caller never gets the database, so nothing closes the connection. The file stays open until the process exits.

A failed first backup runs into this every time. `Controller.RunActionAsync` writes the results of a failed operation with `CreateLocalDatabaseAsync(dbpath, operation: null, ...)`, which looks up the previous operation. In a new database the failed backup's own operation was never committed, so the lookup throws "LocalDatabase does not contain a previous operation.". The handler logs that as a `FailedWriteOperation` warning and moves on, and the connection is left open.

Measured on master:

| Condition | After the failure |
|---|---|
| New database, destination missing (or folder cannot be created) | the database file is still open |
| Existing database, same failure | closed |
| With or without retries | same, retries are not involved |
| Successful backup | closed |

`SQLiteLoader` uses `Pooling=false`, and the file stayed open after a GC, so the connection was still referenced. A temporary probe that recorded where each connection was opened pointed at the failure handler in `Controller.cs`.

The effect: a later backup on the same database still works. However, the file handle stays open for the life of the process, so on Windows the database file cannot be deleted until then.

## The change

When the setup fails, `CreateLocalDatabaseAsync(string path, ...)` releases what it set up: the commands, the reusable transaction and the connection. Then it passes the error on. It does not call `DisposeAsync` on the instance, because a derived database may not be initialized at that point.

This fixes every caller that opens a database by path, including the other `operation: null` writes in `Controller`.

## Red to green

`Duplicati/UnitTest/FailedOperationDatabaseTests.cs` (new): a first backup to a missing destination, with folder creation off and no retries, followed by a check that the database file is no longer open. On Windows the check is an exclusive open; on Linux it looks for the file in `/proc/self/fd`, as an exclusive open does not conflict with SQLite's locks there.

| | Before | After |
|---|---|---|
| The database is still open after the failed backup | **red** | green |

Measured on Windows and on Linux (ext4, WSL). Related tests pass (16: aborted backups and restores, the server lifecycle test, consistency checks and others).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
