## What happens

`HttpReportStatus` posts the operation status as JSON to `--http-report-status-url`. The last report is built in `OnOperationCompletedAsync` from the exception alone: `Completed` with no `ErrorMessage` when the operation did not throw, and `Failed` with the exception's message when it did.

- **An operation can finish without throwing and still fail.** For instance, a restore that cannot restore a file logs the error, restores nothing, and returns with `ParsedResult` `Error`. The status report then says `Completed` with no error, so a monitor reading it sees a failed restore as successful. The other reporting modules use `ParsedResult` and report it as an error. This is the same gap as the server's task state in #7365, on the reporting side.
- **The `Failed` report sends the exception's message with its paths.** The module redacts paths in the log lines it sends unless they are allowed, and the other reporting modules redact the whole report (`ReportHelper` applies `SensitiveDataFilter.RedactPaths` to the body and subject after filling in the template). The exception's message, however, went out as it was.

  Measured by pointing `http-report-status-url` at a local server and running a backup to a destination that does not exist, with the default options. The `Failed` report's `errorMessage` held the full path of the missing folder, while the log line for the same failure in the same report had it redacted.

## The change

- When the operation did not throw and its `ParsedResult` is `Error` or `Fatal`, the completed report carries an `ErrorMessage`: the error itself when there is one, otherwise `Got N error(s)`, as in the notification the server registers. `Status` stays `Completed` and `IsCompleted` is unchanged, as the operation did run to the end. A result with only warnings reports no error, as before.
- The error in both cases, the exception's message and the result's error, is redacted like the log lines: paths are removed unless `http-report-status-allow-paths-in-log-messages` or `allow-paths-in-log-messages` allows them.

## Red to green

Five tests in `HttpReportStatusTests`. The completed-with-errors tests pass a real `RestoreResults` with messages logged through its `WriteMessage`, the way the engine logs them. The existing tests pass `null` as the result, which still works.

| Test | Before | After |
|---|---|---|
| Completed, one error whose text contains a path | **red**: no `ErrorMessage` | green: the error, with the path redacted |
| Completed, three errors | **red**: no `ErrorMessage` | green: `Got 3 error(s)` |
| Completed, only a warning | green: no `ErrorMessage` | green (guard) |
| Failed, the exception's message contains a path | **red**: the path is sent | green: redacted |
| Failed, paths allowed | green: the path is kept | green (guard) |

Measured on Windows and on Linux (ext4, WSL). `HttpReportStatusTests`, `ReportModuleTests` and `ReportHelperOperationsTests` pass (36).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
