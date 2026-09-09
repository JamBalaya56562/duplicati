Title: Report a failure in the option setup to the report modules

## Summary

`Controller.RunActionAsync` sets up the report modules (`IReportModule`, for example `--http-report-status-url`) right after `SetupCommonOptions`. When `SetupCommonOptions` threw, the setup was skipped. The modules then got neither the start nor the failure of the operation. This happens when an option fails validation (for example a `--prefix` with a hyphen), and when a module's `OnStart` throws.

Now the report modules are set up before the exception is passed on. The modules that were already loaded get the start and then the failure, through the existing error path. Nothing changes when `SetupCommonOptions` succeeds.

This is separate from the fix for #3605 (`fix/notify-on-required-script-failure`), which covers the generic report modules (`--send-mail-*`, `--send-http-*`) that were never configured when a run-script failed. The two changes touch different lines and do not depend on each other.

Commit: [3e86961c58a9c144036a8ac95998e933e5b69d10](https://github.com/JamBalaya56562/duplicati/commit/3e86961c58a9c144036a8ac95998e933e5b69d10)

## Testing

- New `ReportModuleTests.ReportModuleReceivesFailureFromOptionValidation` runs a backup with the recording report module and `--prefix=has-hyphen`. It expects the `UserInformationException`, one start call and one completion call reporting `Failed`.
  - On master it fails: `OnOperationStartedAsync should be invoked once`, expected 1 but was 0.
  - With the change it passes.
- `dotnet test --filter FullyQualifiedName~ReportModuleTests`: 24 passed, 0 failed.
- The build has no new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
