## Summary
Closes #2654.

Opening the restore page while the backup ran made the listing open the same local database, and the user got SQLite's "database is locked". Since https://github.com/duplicati/duplicati/commit/f690297d1b03fef9f4e0bd42c8f074b1d31bddff the server keeps a lock per database for the running task, and an immediate task fails at once with `DatabaseLockedException`. The lock tracker has tests of its own, but no test checked that `RunImmediatelyAsync` refuses the listing while the database is held. This PR only adds a test.

## Testing
- New test `QueueRunnerServiceDatabaseLockTests.ListingForRestoreFailsAtOnceWhileTheBackupHoldsTheDatabaseAsync`. It holds the lock as the queue runner does for a backup, starts the listing the restore page sends, and checks that it ends at once with `DatabaseLockedException` and that the backup keeps its lock. Without the check in `RunImmediatelyAsync` it fails: `Expected: <Duplicati.Library.Interface.DatabaseLockedException>`, `But was: <System.NullReferenceException …>`. On master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)