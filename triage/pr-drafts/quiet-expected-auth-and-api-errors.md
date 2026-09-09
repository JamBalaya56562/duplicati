# Stop logging expected refresh failures and API answers as errors

On [the forum](https://forum.duplicati.com/t/22685), after an update to 2.4.0.0 on Windows, the event log showed:

```
Category: Microsoft.AspNetCore.Diagnostics.ExceptionHandlerMiddleware
EventId: 1
RequestPath: /api/v1/auth/refresh
An unhandled exception has occurred while executing the request.
Duplicati.WebserverCore.Exceptions.UnauthorizedException: Failed to refresh token
```

As was said in the thread, this comes from loading the page with a refresh cookie that is no longer valid, is not an error as such, and is noisy. There are two sources:

1. **The server log.** The refresh endpoint logged every failure as `RefreshTokenError` at the error level. A token that is expired, signed with another key, malformed or already used is now logged at the verbose level, with the reason. Other failures, such as a database error, are still errors. Reuse of a token family is still logged as a warning by `LoginProvider`.
2. **The event log of Windows.** 7436d1271 turned off the `Microsoft.AspNetCore.Diagnostics` category, so that the exceptions the endpoints throw for an expected answer are not logged by ASP.NET. On Windows, the host adds the event log provider with a filter rule of its own, and a rule for a provider takes precedence over the general rules, so the category was still logged there. Every 400, 401 and 404 answer was written to the event log as an error. The category is now turned off for the event log provider as well, on Windows.

## Testing

New tests in `ServerApiIntegrationTests`:

- `AnInvalidRefreshCookieIsNotLoggedAsAnErrorAsync`: posts `/api/v1/auth/refresh` with a cookie that is not a token, expects 401, and reads the errors from `/api/v1/logdata/poll`. On master the poll has "Failed to refresh token" at the error level; with the change it does not.
- `TheExceptionHandlerLogsNothingAsync`: checks that the logger of `ExceptionHandlerMiddleware` from the server's `ILoggerFactory` is not enabled for errors. On master (Windows) it is; with the change it is not.

`ServerApiIntegrationTests` and the auth, login and JWT tests: 76 passed on Windows. No new warnings in the changed files.

The event log of the test machine had 10 `ExceptionHandlerMiddleware` events from the test runs on master in the 3 hours before (unauthorized, not found, bad request answers), and none from the run with the change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
