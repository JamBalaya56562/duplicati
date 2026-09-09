Commit: [bdfbf6aa69c2e1a88b2862b339ff6f8be208cd78](https://github.com/JamBalaya56562/duplicati/commit/bdfbf6aa69c2e1a88b2862b339ff6f8be208cd78)

## Summary

Since 2.4.0.1, every backup can end with a `SlowQueryDetected` warning (and an orange tray icon) for a trivial query, e.g. `Query still running after 3493.9s in ExecuteReaderEnumerableAsync: SELECT "ID" FROM "Fileset"` ([forum topic 22796](https://forum.duplicati.com/t/22796)).

`ExecuteReaderEnumerableAsync` opened the `SlowQueryMonitor` scope around the whole iterator, including `yield return`. The time a caller spent on each row was therefore counted as query time. `VerifyConsistencyAsync` keeps the `Fileset` reader open while it runs two `COUNT` queries per fileset, so on a large backup the outer `SELECT "ID" FROM "Fileset"` was reported as "running" for the whole verification.

The scope now covers only `ExecuteReaderAsync` and each `ReadAsync`, which is what the synchronous `ExecuteReaderEnumerable` already does (it monitors only `ExecuteReader`). This fixes every caller of the enumerable rather than only `VerifyConsistencyAsync`. The `Logging.Timer` profiling entry still spans the whole enumeration, as before.

A query whose rows are individually slow to produce is still reported, because each `ReadAsync` is monitored.

## Testing

Two tests in `SQLiteTests`, using the existing 1 s threshold harness:

- `TimeSpentByTheCallerBetweenRowsIsNotReportedAsync`: holds each of 3 rows for 1.5 s. Before the fix it failed with four warnings (`Query still running after 1.0s … 4.0s in ExecuteReaderEnumerableAsync: SELECT ID FROM TestTable`); after the fix it passes.
- `ASlowRowInAnEnumeratedReaderIsReportedAsync`: the last row calls a 2.5 s function, so the wait happens in `ReadAsync` rather than when the reader is created. It is reported both before and after the fix.

`dotnet test --filter FullyQualifiedName~SQLiteTests`: 6/6 passed after the fix (5/6 before). No new build warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
