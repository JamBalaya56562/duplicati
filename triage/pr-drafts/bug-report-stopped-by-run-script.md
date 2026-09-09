Part of #4798

## Summary
A `--run-script-before` script that exits with 1, 3 or an error code stops the operation it runs for, and that includes creating a bug report. No report is made then, so `TargetPath` stays empty. The server still registered that path for download, which failed the task with:

```
SQLite Error 19: 'NOT NULL constraint failed: TempFile.Path'.
```

This is the error in #4798. When there is no report, the server now skips registering the download and the "Bugreport ready" notification.

The other symptom in #4798, restore points shown as "undefined" on macOS, is not addressed here. It may come from the same script stopping every operation, but I could not check that.

## Testing
- New test `ServerApiIntegrationTests.BugReportStoppedByTheRunScriptDoesNotFail_Async`. It saves a backup with a run-script-before script that exits with 1, creates a bug report, and checks that the task completes without offering a download. On master it fails with the error above. With the change it passes.
- Tests matching `BugReport`: 15 passed. No new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
