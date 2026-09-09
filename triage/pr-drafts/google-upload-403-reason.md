Branch: `fix/google-upload-403-reason` on JamBalaya56562/duplicati, commit [6901d170d5885feb6abc52e36c7be199f8bbea09](https://github.com/JamBalaya56562/duplicati/commit/6901d170d5885feb6abc52e36c7be199f8bbea09).
**Stacked on #7559** (parent [287e003f384031b14fa8e69ab5643b3e7dcb3b82](https://github.com/JamBalaya56562/duplicati/commit/287e003f384031b14fa8e69ab5643b3e7dcb3b82), `fix/google-403-reason`): it reuses the body parser added there. Do not open until #7559 is merged; then rebase onto master (`jj rebase -s <this commit> -d master@upstream`, the #7559 commit drops out) and open.
No related open issue found, so no `Fixes` line.

---

Title: Report Google's error reason and retry rate limits in chunked uploads

## Problem

Follow-up to #7559, which adds Google's error reason to failures that go through `GetResponseAsync`. The chunks of a resumable upload (`GoogleCommon.ChunkedUploadAsync`) and its upload status query are sent with `GetResponseUncheckedAsync`, so:

- a refused chunk fails with only `Unexpected status code: 403`, without the reason;
- the upload's own retry only covers 5xx, so a rate limit (403 `rateLimitExceeded` / `userRateLimitExceeded`, or 429) fails the whole upload, although Google asks for it to be retried and the upload resumed ([Drive API: Upload file data](https://developers.google.com/workspace/drive/api/guides/manage-uploads), [Resolve errors](https://developers.google.com/workspace/drive/api/guides/handle-errors)).

## Change

- An unexpected status on a chunk or on the status query now builds its `HttpRequestException` through the same helper as #7559: same status code and `HttpProtocolError`, message `Unexpected status code: N` plus `Google reason: <reasons>, message: <message>` when the body has them, and `TooManyRequestException` as inner exception for a rate limit. Status 429 counts as a rate limit even without a body.
- The chunk retry now also retries a rate limit, through the existing path: exponential sleep, query the committed range, resume. Any other 4xx still fails at once.
- The body reading in `ThrowWithErrorReasonAsync` is split into `ReadErrorBodyAsync` / `CreateException` so both paths share it; behaviour of #7559's path is unchanged.

## Tests

`GoogleUploadErrorReasonTests` (offline, stub `HttpMessageHandler`: empty folder, upload session, first chunk fails with the given status/body, resume query answers 308 with nothing committed):

| Test | before | after |
|---|---|---|
| `RateLimitedChunkIsResumed` (403 userRateLimitExceeded / 429 rateLimitExceeded / 429 no body) — refused chunk, resume query, full chunk | red ×3 | green |
| `RefusedChunkNamesTheGoogleReason` — 403 insufficientFilePermissions: reason in message, status 403, not a rate limit, not retried | red | green |

```
before: dotnet test ... --filter "FullyQualifiedName~GoogleUploadErrorReasonTests"  -> 失敗: 4、合格: 0
after:  dotnet test ... --filter "FullyQualifiedName~GoogleUploadErrorReasonTests|FullyQualifiedName~GoogleApiErrorReasonTests|FullyQualifiedName~GoogleDrive|FullyQualifiedName~GoogleCredential|FullyQualifiedName~JsonWebHelper" -> 失敗: 0、合格: 36
```

No new build warnings (0 個の警告).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
