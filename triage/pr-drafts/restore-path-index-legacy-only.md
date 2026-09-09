Part of #7538

## Summary
A restore keeps the list of the files to restore in a temporary table, and the temporary tables are kept in memory (`temp_store=MEMORY`). The table had an index on `"Path"`. For a restore of 100,000 small files, the index held 15.9 MB of the 55 MB the temporary tables used, about as much as the rows themselves (17.2 MB).

Only the legacy restore looks files up by their path, in `GetFilesAndSourceBlocksFastAsync` (`WHERE "Path" = @Path`), when it looks for local copies of their blocks. The queries of the new restore compare paths with `SUBSTR`, `LOWER` or `LENGTH`, and SQLite cannot use the index for those. In `EXPLAIN QUERY PLAN`, the only query that used it was `ORDER BY LENGTH("Path") DESC`, as a covering scan, and that still sorts in a temporary B-tree. `COUNT(DISTINCT "Path")` uses a temporary B-tree with or without the index.

The index is now made by `CreateFilePathIndexAsync`, which the restore calls when it builds the block list. Only the legacy restore does that, since #7964. The indexes on `"BlocksetID"` and `"MetadataID"` stay: the new restore's queries use them, and they are 1.2 MB each.

This is on top of #7964.

## Measured
Restore of 100,000 small files with `--restore-cache-max=0b`, Release build on Windows. Two runs each, alternating between #7964 and this change. Peak private bytes:

| | #7964 | this change |
|---|---|---|
| With the local database | 284 MB, 287 MB | 279 MB, 275 MB |
| Without a local database | 351 MB, 365 MB | 343 MB, 344 MB |

The run times varied between 500 and 740 s in both, with no difference between them.

Without a local database, the saving is smaller than the index. The recreate before the restore uses the same connection, and its temporary tables reach 42 MB. Memory used by a temporary store is not returned until the connection closes, so the restore's temporary tables fit into it once they are under 42 MB.

## Testing
- New test `RestoreFilePathIndexTests.OnlyTheLegacyRestoreIndexesThePathsAsync`, for the new and the legacy restore. It restores two files and looks for the statement that creates the index in the logged SQL. On #7964 the new restore case fails: `The new restore indexed the paths it does not look up`, `Expected: False`, `But was: True`. With the change both cases pass, and the restored files match the source.
- Tests matching `Duplicati.UnitTest.Restore`, `Issue3231` and `AlternateDataStreamTests` (both restore flows): 223 passed, 7 skipped. No new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
