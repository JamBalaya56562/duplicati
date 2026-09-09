Part of #7538

## Summary
A restore keeps the list of the files to restore in a temporary table, and the temporary tables are kept in memory (`temp_store=MEMORY`). `SetTargetPathsAsync` filled `"TargetPath"` for every row with one to five `UPDATE` statements. For a restore of 100,000 small files, this added 18.4 MB to the 55 MB the temporary tables used.

Every rule in `SetTargetPathsAsync` computes the target path from `"Path"`: it strips the common prefix, rewrites drive letters and UNC prefixes, swaps separators across OSes, and prepends the destination. `"TargetPath"` is now a virtual generated column. `SetTargetPathsAsync` adds it with `ALTER TABLE … ADD COLUMN … GENERATED ALWAYS AS (…) VIRTUAL`, so SQLite computes it when it is read and does not store it. The queries that read `"TargetPath"` are unchanged.

The expression is built by `GetTargetPathExpression`, which follows the old statements in the same order. A generated column cannot use parameters, so the destination and the Windows root are inlined as quoted SQL string literals.

Two places set a target path for a single file: a file renamed because its target exists (`UpdateTargetPathAsync`), and a virtual entry mapped to its original location (`MapVirtualEntriesToOriginalPathsAsync`). These are stored in a new column, `"TargetPathOverride"`, which the computed column uses first. A virtual entry with no recorded original path used to get a `NULL` target path. It now gets an empty override, since a `NULL` override falls back to the computed path. The callers already treat an empty target path the same as `NULL`.

This is on top of the change that indexes the paths only for the legacy restore.

## Measured
Restore of 100,000 small files with `--restore-cache-max=0b`, Release build on Windows. Runs alternated between the base and this change. Peak private bytes:

| | base | this change |
|---|---|---|
| With the local database (2 runs each) | 275 MB, 276 MB | 237 MB, 236 MB |
| Without a local database (1 run each) | 341 MB | 334 MB |

The run times were 513–720 s for the base and 428–598 s for this change, so the computed column did not make the restore slower.

Without a local database the saving is smaller. The recreate before the restore uses the same connection and grows the temporary store to 42 MB. Memory used by a temporary store is not returned until the connection closes.

## Testing
- New test `RestoreTargetPathTests.TheTargetPathsAreComputedAndNotStoredAsync`. It checks that `"TargetPath"` is a virtual column (`pragma_table_xinfo` reports `hidden = 2`), reads the computed path of a restored file, and checks that a path set with `UpdateTargetPathAsync` is kept. On the base it fails with `The target paths are stored with every file`, `Expected: 2`, `But was: 0`.
- New test `TheComputedTargetPathMatchesTheRestoreRules`, with 10 cases covering each branch of the old statements: same OS, Windows paths on Linux, Linux paths on Windows, drive letters, UNC paths, a common prefix, and a quote in the destination. The expected values come from reading the old statements. A case that restores to a folder runs only on the OS it simulates, because the destination gets the directory separator of the OS that runs the restore. On Windows, 8 cases ran and 2 were skipped.
- Tests matching `Duplicati.UnitTest.Restore`, `Issue3231` and `AlternateDataStreamTests`: 232 passed, 9 skipped. No new warnings.
- Not tested: the virtual-entry mapping (`\\duplicati\mssql\` and similar mount points). There are no unit tests for it, and it runs only on Windows with those source providers.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
