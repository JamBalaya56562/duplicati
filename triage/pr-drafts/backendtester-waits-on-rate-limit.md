Title: Wait out rate limits in the backend tester

## Summary

The Google Drive live test fails now and then with `403 rateLimitExceeded` ("Quota exceeded for quota metric 'Queries' and limit 'Requests per minute'"), for example in [job 121715208760](https://github.com/duplicati/duplicati/actions/runs/40331419510/job/121715208760). The backend reports the rate limit correctly (the reason is in the log, and the inner exception is a `TooManyRequestException`), but the backend tester retried the download after 1 and 2 seconds. The limit is counted per minute, so it was still in force and all 3 attempts failed within 3 seconds.

The tester's retry delay now depends on the failure. When the exception, or one inside it (including an `AggregateException`), is a `TooManyRequestException`, the tester waits as long as its Retry-After says (a delay or a date), or one minute when there is none. A Retry-After shorter than the usual backoff keeps the backoff. Other failures keep the 1 s, 2 s, ... delays as before.

Only the tester changes. The backends and the retry handling in Duplicati itself are not touched.

Commit: [f80b327e0579433d186f2c9d1cb510a95c28bf6b](https://github.com/JamBalaya56562/duplicati/commit/f80b327e0579433d186f2c9d1cb510a95c28bf6b)

## Testing

- New `BackendTesterRateLimitTests` (6 tests) call `Program.GetRetryDelay`, the function the retry loop now uses.
  - With the old delay (`Utility.GetRetryDelay(1 s, attempt, true)` for every failure), the 4 rate-limit tests fail: expected 1 min / 30 s / 45 s, but was 1 s.
  - With the change: all 25 `BackendTester` tests pass.
- The live Google Drive test itself was not run (it needs the repository's secrets).
- No new compiler warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
