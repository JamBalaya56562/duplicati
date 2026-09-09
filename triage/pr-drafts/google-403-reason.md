Branch: `fix/google-403-reason` on JamBalaya56562/duplicati, commit [287e003f384031b14fa8e69ab5643b3e7dcb3b82](https://github.com/JamBalaya56562/duplicati/commit/287e003f384031b14fa8e69ab5643b3e7dcb3b82), base upstream master 71981c36.
No related open issue found (searched: "google drive 403", "google drive forbidden", "userRateLimitExceeded", "Rate Limit Exceeded", "google drive rate limit", "google cloud storage 403/forbidden"); so no `Fixes` line.

---

Title: Report Google's error reason and mark rate limits on 403

## Problem

Google answers both a missing permission and a per-user rate limit with `403 Forbidden`; only the error body tells them apart ([Drive API: Resolve errors](https://developers.google.com/workspace/drive/api/guides/handle-errors) lists `userRateLimitExceeded` / `rateLimitExceeded` as 403 and asks for exponential backoff).

`JsonWebHelperHttpClient.GetResponseAsync` calls `EnsureSuccessStatusCode` and the Google clients did not override `AttemptParseAndThrowExceptionAsync`, so the body was dropped:

- A log only shows `Response status code does not indicate success: 403 (Forbidden).` — the Backend Live Tests Google Drive job fails this way on list/get/delete and the reason cannot be told from the log.
- Google Cloud Storage turns any 403 on a listing into `FolderMissingException`, so a rate-limited listing is reported as a missing bucket (and the caller may try to create it).

## Change

- `GoogleCommon.ThrowWithErrorReasonAsync` reads the error body of a failed request (bounded by a 30 s timeout; an unreadable or non-Google body leaves the failure unchanged) and rethrows an `HttpRequestException` with the same status code and the message extended with `Google reason: <reasons>, message: <message>`.
- A rate limit (`rateLimitExceeded`, `userRateLimitExceeded`, or status 429) carries the existing `TooManyRequestException` as the inner exception. Other 403s (e.g. `insufficientFilePermissions`) keep the original exception as inner and fail as before.
- It is hooked in the same way Box and Dropbox do it: a small `GoogleOAuthHelperHttpClient` overriding `AttemptParseAndThrowExceptionAsync`, used by Google Drive and Cloud Storage, and the same override on the Cloud Storage `ServiceAccountHttpClient`.
- Cloud Storage's listing no longer maps a rate-limited 403 to `FolderMissingException`; any other 403 still does.
- Cloud Storage gets an internal constructor taking an `HttpClient` (same seam Google Drive already has) for the tests.

Retrying itself is unchanged: `BackendManager` already retries any failed operation with `--retry-delay` / `--retry-with-exponential-backoff`; the rate limit is now visible in the retry log message and marked for callers that look for `TooManyRequestException`.

## Tests

`GoogleApiErrorReasonTests` (offline, stub `HttpMessageHandler` answering the token request and failing every other request with 403 + a Google error body):

| Test | before | after |
|---|---|---|
| `DriveFailureNamesTheGoogleReason` (userRateLimitExceeded / rateLimitExceeded / insufficientFilePermissions) | red ×3 | green |
| `DriveRateLimitIsMarkedForRetry` (×2) | red ×2 | green |
| `CloudStorageRateLimitIsNotAMissingBucket` | red | green |
| `DrivePermissionErrorIsNotARateLimit` | green | green |
| `DriveFailureWithoutAGoogleBodyIsUnchanged` | green | green |
| `CloudStoragePermissionErrorIsStillAMissingBucket` | green | green |

```
dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --filter "FullyQualifiedName~GoogleApiErrorReasonTests"
before: 失敗: 6、合格: 3、合計: 9
dotnet test ... --filter "FullyQualifiedName~GoogleApiErrorReasonTests|FullyQualifiedName~GoogleDrive|FullyQualifiedName~GoogleCredential|FullyQualifiedName~JsonWebHelper"
after:  失敗: 0、合格: 32、合計: 32
```

No new build warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
