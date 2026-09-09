Branch: `chore/remove-dead-log-queue` (JamBalaya56562/duplicati)
Title: Remove the unused log message queue from the results

> Open only after `fix/report-failures-in-job-log` is merged: the branch is currently stacked on it (it touches the same `WriteResultsAndCommitAsync`). Rebase it onto master first, so the PR carries only its own commit.

## Summary

`BasicResults` kept a queue of log messages (`m_dbqueue` of `DbMessage`, guarded by `m_lock`) that `FlushLogAsync` wrote to the `LogData` table every time the results were written. Nothing has put anything into the queue since 2018:
- [842fd965439c6f1e6aac2d9ecaedfac1981e16c9](https://github.com/duplicati/duplicati/commit/842fd965439c6f1e6aac2d9ecaedfac1981e16c9) (the new logging system) removed the last calls to `LogDbMessage`, the only method that enqueued.
- [9e0b031feed4678f596d6d86e9001f683e27755b](https://github.com/duplicati/duplicati/commit/9e0b031feed4678f596d6d86e9001f683e27755b) then removed `LogDbMessage` itself as unused, but left the queue, its lock and the flush behind.

Since then `FlushLogAsync` has only ever taken a lock and drained an empty queue. This change ([fcd3a214a6960cdc19d4a9fd7b225ebbabf7d58e](https://github.com/JamBalaya56562/duplicati/commit/fcd3a214a6960cdc19d4a9fd7b225ebbabf7d58e)) removes `DbMessage`, `m_dbqueue`, `m_lock`, `FlushLogAsync` and its one call in `LocalDatabase.WriteResultsAndCommitAsync`, along with the usings that only they needed. No behaviour changes: since then the job log has only contained the serialized result.

## Testing

- No other references: `grep -rn "m_dbqueue|DbMessage|FlushLogAsync"` over the repository finds only the removed code (the `m_dbqueue` in `BackendManager.DatabaseCollector` is a separate field). The same search over every branch on duplicati/duplicati found enqueueing code only on branches whose last commit is from 2018 or earlier, and no caller of `FlushLogAsync` other than the same one in `WriteResultsAndCommitAsync`.
- `dotnet build Duplicati.slnx`: 0 errors; the only warnings are the existing NuGet advisories (NU1902/NU1903), none in C# code.
- `ReportResultLogTests`, `ResultSerializationTests`, `Issue6538`, `ReportModuleTests`, `HttpReportStatusTests`, `ReportHelperOperationsTests` and `SyncHandlerTests`: 80 passed, 1 skipped, 0 failed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
