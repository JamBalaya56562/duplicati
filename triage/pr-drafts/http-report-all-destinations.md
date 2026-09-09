## Summary

When several HTTP report targets are configured (`--send-http-url`, `--send-http-form-urls`, `--send-http-json-urls`), a target that kept failing stopped the report from reaching the targets after it.

The `??=` in the loop was only part of it: `RetryHelper.Retry` rethrows the last failure once the retries are used up, so the exception left the loop at the first failing target, and the remaining targets were never tried.

Each target is now tried on its own. After all of them, the first failure is rethrown (with its original stack trace), so `ReportHelper.OnFinish` logs `ReportSubmitError` exactly as before. Every failed attempt is still logged per URL as `HttpResponseError`. With a single target the behaviour is unchanged.

Commit: [b9b79b270fbf233300c3ecf85cbb26e05c464f70](https://github.com/JamBalaya56562/duplicati/commit/b9b79b270fbf233300c3ecf85cbb26e05c464f70)

Fixes #7454

## Testing

New `SendHttpMessageTargetsTests` drives the real module (`Configure` → `OnStart` → `OnFinish`) against a local `HttpListener` that answers `/fail` with 500 and anything else with 200, and asserts the requests the server received.

- `FailingTargetDoesNotStopTheNextOne` (form target fails, JSON target works): on master the server got only `/fail`; with the fix it gets `/fail`, `/ok`, and one `ReportSubmitError` is logged.
- `EveryFailingTargetIsTried`: two failing targets are both tried; one `ReportSubmitError`.
- `SingleFailingTargetIsReportedOnce` / `SingleWorkingTargetLogsNoWarning`: the single-target behaviour (one request, one `HttpResponseError`, one `ReportSubmitError` carrying the `HttpRequestException`; no warning on success). These pass both before and after the change.

```
dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --filter "FullyQualifiedName~SendHttpMessageTargetsTests"
master:  Failed 2, Passed 2 (FailingTargetDoesNotStopTheNextOne, EveryFailingTargetIsTried)
fix:     Passed 4
```

No new compiler warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
