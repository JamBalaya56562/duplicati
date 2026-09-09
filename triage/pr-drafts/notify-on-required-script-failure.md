Title: Report a run-script-before failure to the report modules

## Summary

When a `--run-script-before` script fails the operation (exit code 3, 5 or any other error code), or a `--run-script-before-required` script fails, no report is sent by `--send-mail-*`, `--send-http-*` and the other report modules.

The cause is in `Controller.SetupCommonOptions`: each module is configured and started in turn, and the run-script module comes first (priority 100). When its `OnStart` throws, the loop stops, so the report modules after it are never configured, and their `OnFinish` returns early because `m_isConfigured` is false.

#5245 tried to fix this by configuring all modules before starting any, and was closed because a script can set options for the modules after it. Since [f6094badd](https://github.com/duplicati/duplicati/commit/f6094baddb15ffd0e7677507c9103db243d39a6d) (the fix for #6314) the load order is defined by `IGenericPriorityModule`, so this change keeps the order as it is: each module is still configured and started in turn and sees the options set by the scripts before it. The only change is that a failure in `OnStart` no longer stops the loop. The remaining modules are configured and started, and then the first failure is rethrown. Later `OnStart` failures are logged as warnings.

A script that exits with 1 ("OK, don't run operation") still stops the loop at once, as before. This means a script that skips the run on purpose does not start sending a report each time it skips; with the default level `all` it would otherwise do that.

Commit: [36d44b54517063d2cd8538a93cd000618a4556c3](https://github.com/JamBalaya56562/duplicati/commit/36d44b54517063d2cd8538a93cd000618a4556c3)

Fixes #3605

## Testing

- New `RunScriptTests.ReportIsSentWhenScriptStopsOperationAsync` runs a backup with a script and `--send-http-url` pointing to a local `HttpListener`, then asserts which reports arrive.
  - Before the change: the `run-script-before` exit 5 and `run-script-before-required` exit 1 cases failed with no request received.
  - After the change: all 4 cases pass (exit 3, exit 5, and a failed required script each send one report; exit 1 sends none).
- `dotnet test --filter FullyQualifiedName~RunScriptTests`: 28 passed, 0 failed.
- The build has no new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
