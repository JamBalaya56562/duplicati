`verify` and `cleanup` scanned every `*.sqlite` file below the data folder, so a file that is not a Duplicati database was listed as orphaned, and `cleanup --force` deleted it. This matters when `--datafolder` points at a folder shared with other applications.

The filesystem scan now only picks up files that `Helper.ExamineDatabaseAsync` can read as a Duplicati database. Databases referenced from `dbconfig.json` or the server database are reported as before. A side effect is that an unreferenced `.sqlite` file that cannot be opened at all is now left alone instead of being deleted.

Filtering by `IsRandomlyGeneratedName` (as the upgrade scan does) was not used, because CLI databases created with `--backup-name` get a non-random name and can legitimately be orphaned.

Test: `DatabaseToolCleanupScanTests.CleanupKeepsSqliteFilesThatAreNotDuplicatiDatabasesAsync` fails before the change (the two foreign files are listed as orphaned) and passes after.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
