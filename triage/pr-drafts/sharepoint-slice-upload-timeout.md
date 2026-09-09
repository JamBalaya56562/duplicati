# SharePoint: time out upload chunks that stop moving

Branch: `fix/sharepoint-slice-upload-timeout` (commit [6578a19229b85458e49c14dbd052d09a1c44d374](https://github.com/JamBalaya56562/duplicati/commit/6578a19229b85458e49c14dbd052d09a1c44d374)). It is stacked on `fix/async-withtimeout-aborts` ([0b3207cb0b0b90315a5c7baddf069a0d30fdbc82](https://github.com/JamBalaya56562/duplicati/commit/0b3207cb0b0b90315a5c7baddf069a0d30fdbc82), master 922a7c73), because it uses that branch's context handling. **Open this PR only after `fix/async-withtimeout-aborts` is merged**, and rebase it onto master first so that it carries only its own commit.

## Problem

`UploadFileSlicePerSlice` sends a large file in chunks (`chunk-size`, 4 MB by default), one `ctx.ExecuteQueryAsync()` per chunk. These calls had no timeout. Only the final `FinishUpload` with an empty stream was wrapped in `WithTimeout`.

The chunk content is wrapped in `ObserveReadTimeout`, but nothing timed the wait for the server's answer after the chunk was sent. CSOM's `ExecuteQueryAsync` takes no token. A server that stopped answering kept the upload, and the backup, waiting.

## Change

- Each chunk query now runs through `ExecuteQueryWithIdleTimeoutAsync`. The chunk stream is wrapped in a small `ActivityStream` that records when it was last read. The query fails with `TimeoutException` when, for the length of `read-write-timeout`, the chunk has not been read and no answer has come.
  - This catches both a send that stopped and an answer that never came.
  - A slow but steady upload is not cut off. Timing the whole chunk instead would fail any chunk that takes longer than 30 s to send, for example a 4 MB chunk below about 1.1 Mbit/s.
  - This matches the documented meaning of the option: "If no activity is detected in this interval, a timeout error is raised".
- After a timeout, the context is not handed out again, as in `ExecuteQueryWithTimeoutAsync`, because the query keeps running on it.
- A `read-write-timeout` of 0 or infinite keeps the old behaviour (no timeout).
- For seams, `UploadFileSlicePerSlice` becomes internal, and an internal `ChunkStreamCreated` hook gives tests the stream that the context would send.

**After a timeout:** the upload session (`StartUpload`/`ContinueUpload`) is not cancelled, so it stays open on the server. The partly uploaded file may remain in the folder until SharePoint discards the session. This is the same as when a sliced upload fails for any other reason today.

`BackendManager` retries a failed put under a new remote name (`RenameFileAfterError` in `BackendManager.PutOperation.cs`), on a new backend instance. So the retry starts a new upload from the beginning, with a new upload ID, and the leftover file does not block it.

## Testing

New unit tests in `SharePointSliceUploadTimeoutTests`, with `read-write-timeout=1s`. They use a `ClientContext` subclass whose `ExecuteQueryAsync()` runs test code instead of sending a request.

| Test | What the fake query does | master | this branch |
|---|---|---|---|
| `ChunkThatIsNotSentTimesOut` | never reads the chunk and never completes | had not returned after 15 s | `TimeoutException`, and the next context is a new one |
| `ChunkWithoutAnAnswerTimesOut` | reads the whole chunk, then never completes | had not returned after 15 s | `TimeoutException`, and the next context is a new one |
| `ChunkThatIsSentSlowlyIsNotCutOff` | reads the 10-byte chunk one byte every 300 ms (3 s in all), then completes | passes | passes: no `TimeoutException` |

`AsyncWithTimeoutAbortTests` from the base branch still passes (6 tests in all).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
