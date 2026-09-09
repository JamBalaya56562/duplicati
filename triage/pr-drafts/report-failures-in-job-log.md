Branch: `fix/report-failures-in-job-log` (JamBalaya56562/duplicati)
Title: Show report send failures in the job log

## Summary

When a report sent after an operation (HTTP, email, Telegram, ...) fails, the operation turns into a warning and the UI shows "Warnings", but the job log ("Show log") shows nothing to explain it. Reported on the forum in [Unlogged warnings](https://forum.duplicati.com/t/22440), [Useless "warning" alerts, since no details are available](https://forum.duplicati.com/t/22616) (where it was agreed the warning should appear in that backup's log) and [Warning count bug?](https://forum.duplicati.com/t/20926).

The cause is ordering: `Controller` writes the result to the `LogData` table and commits, and only then runs the report modules in `OperationCompleteAsync`. The order cannot simply be swapped, because the reports carry the result and log of the run. The job log shown by the UI is the `Result` row's JSON, so a warning logged after it was written never reaches it.

This change ([a4afed7a87455b3ddd0edea59f79c79f256b9483](https://github.com/JamBalaya56562/duplicati/commit/a4afed7a87455b3ddd0edea59f79c79f256b9483)):
- `LocalDatabase.WriteResultsAndCommitAsync` now returns the ID of the `Result` row it wrote, and a new `UpdateResultsAndCommitAsync` replaces that row's JSON.
- `Controller` remembers that row and the number of warnings and errors at the time it was written. After the report modules have run, if that number has changed, the row is re-serialized in place. This covers all the paths that write the result (success, run-script abort, requested abort, failure).
- If nothing new was logged (for example the report was delivered), the row is left exactly as written.
- If the database is gone or the update fails, the job log is left as it was; the failure is logged at Verbose level so it does not itself change the outcome of the operation.

This was addressed once before: [5046edef494c460a2e982aab60490c160074bcf3](https://github.com/duplicati/duplicati/commit/5046edef494c460a2e982aab60490c160074bcf3) wrote the results a second time after the modules, [0817b60509ee735a585e094411a0c6902c02bc8f](https://github.com/duplicati/duplicati/commit/0817b60509ee735a585e094411a0c6902c02bc8f) replaced that with running the modules first ("rather than re-emitting the same results"), and [4ae9ab7089a96e55f3190ec1292ab937dd5f69c2](https://github.com/duplicati/duplicati/commit/4ae9ab7089a96e55f3190ec1292ab937dd5f69c2) moved the modules back after the write when remote synchronization stopped being a module. This change keeps that order and updates the existing row in place, so no second result entry appears in the log.

Appending a separate log row instead was considered, but the job log UI parses every `LogData` row as a result JSON, so a plain-text row would break the log view.

Side effect worth noting: when the row is rewritten, it is serialized after auto-vacuum has run, so `VacuumResults` (previously always `null` in the stored result, per the comment in `Controller`) is now included in that case. When the row is not rewritten, nothing changes.

## Testing

New `ReportResultLogTests`:
- `AFailedReportIsShownInTheJobLogAsync` backs up with `--send-http-json-urls=http://127.0.0.1:9/` (connection refused). Before the fix the stored result had `"ParsedResult": "Success"` and `"Warnings": null` while the returned result held `ReportSubmitError`; after the fix the stored result holds `ReportSubmitError`, the warning count matches and `ParsedResult` is `Warning`.
- `ADeliveredReportLeavesTheJobLogAloneAsync` delivers the report to a local listener with `--auto-vacuum=true` and checks the stored result was not rewritten (`VacuumResults` stays `null`). Removing the warning/error count check makes it fail.

Also ran `ResultSerializationTests`, `Issue6538`, `ReportModuleTests`, `HttpReportStatusTests` and `ReportHelperOperationsTests`: 57 passed, 0 failed. No new build warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
