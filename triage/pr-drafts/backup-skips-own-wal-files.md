Fixes #1757

## What happens

A backup leaves out the journal file of its own local database (`BackupHandler.GetBlacklistedPaths`), so that it does not read the file while it writes to the database. That was #5603, fixed in [`30075265`](https://github.com/duplicati/duplicati/commit/300752652fbdd645d19f41eebd5e4a6b93693bbe).

Since [`322e4f15`](https://github.com/duplicati/duplicati/commit/322e4f15e4b39128821279a662fc1ee0d3d59170) the databases use write-ahead logging (`journal_mode=WAL` in `SQLiteLoader`), so the files SQLite keeps next to an open database are `-wal` and `-shm`. A `-journal` file normally no longer exists, and a backup whose source holds its own database reads and stores the `-wal` and `-shm` files. The issue reports these files as locked.

## The change

`GetBlacklistedPaths` also leaves out `<dbpath>-wal` and `<dbpath>-shm`. It is used by the backup, the file count, sync and test-filter, as the `-journal` entry is. The database file itself is still not left out, as before.

## Checked

`OwnDatabaseFilesExcludedTests.ABackupLeavesOutTheWriteAheadLogFilesOfItsOwnDatabase` (new) backs up a folder that holds the backup's own database (`--dbpath` inside the source), then lists the version:

- before: fails, both `own-database.sqlite-shm` and `own-database.sqlite-wal` are stored
- after: passes, neither is stored, and the backup has no warning about them

On my Windows machine the backup did not warn about the files before the change either, so the test shows the files being stored rather than the locked-file warning in the issue. The build reports no warnings in the files this changes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
