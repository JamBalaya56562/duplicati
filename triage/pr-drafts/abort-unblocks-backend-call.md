## What happens

"Stop now" on a backup whose upload is stuck in a backend call that does not observe its cancellation
token never returns. This is one mechanism behind #6461 ("Backup can get stuck after requesting
abort"); it is not claimed to be the only one.

Reproduced with a test backend that wraps `file://` and stalls every upload, in two variants: the stall
observes the token, or it ignores it (the way a transfer stuck in a socket write, or a stream copy that
was never handed the token, behaves). Two uploads in flight (`asynchronous-upload-limit=2`), 40 files
of 64 KB in 100 KB volumes, `AbortAsync()` once both slots are stuck:

| Upload | `BackupAsync` returns after the abort |
|---|---|
| observes the token | 0.2 s |
| ignores the token | **not within 2 minutes** |

### Why

A heap dump of the stuck process (`dotnet-dump`, `dumpasync`) shows the chain:

```
DataBlockProcessor  → BackendManager.PutAsync → QueueTaskAsync → CoCoL.Channel<PendingOperationBase>.WriteAsync
StreamBlockSplitter → DataBlock.AddBlockToOutputAsync → CoCoL.Channel<DataBlock>.WriteAsync
FileBlockProcessor  → StreamBlock.ProcessStreamAsync → CoCoL.Channel<StreamBlock>.WriteAsync
BackupHandler.RunMainOperationAsync → Task.WhenAll(...)
```

`BackendManager.Handler.ExecuteAsync<TResult>` awaits the backend call unconditionally
([BackendManager.Handler.cs:590-615](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Backend/BackendManager.Handler.cs#L590-L615)).
When the call does not end on cancellation, the upload task never completes, `EnsureAtMostNActiveTasksAsync`
keeps the handler loop waiting for a free slot, the request channel is not read, and every producer
upstream blocks on a channel write that has no token. The termination path that gives active transfers
one second and then abandons them (`WaitForPendingItemsAsync`) is in the loop's `finally`, which is only
reached once the loop ends - and it never does.

## The change

`ExecuteAsync<TResult>` awaits the backend call through `UntilCancelledAsync`: `Task.WhenAny(call,
cancellation)`. When the token fires first, the call is left to end on its own (its outcome is observed
so it does not surface as an unobserved exception), the backend instance is marked not-reusable and
disposed by the existing `using`, and an `OperationCanceledException` goes to `ExecuteWithRetryAsync`,
which already turns a cancelled token into `op.SetCancelled()`. The awaiting `PutAsync` is released,
the producers behind it unwind through the channels, and `BackupAsync` ends with the cancellation.

Nothing changes for a backend that observes the token: its call ends first and the result is returned
as before. Nothing changes without a stop: the token is never cancelled.

## Red to green

`--filter "FullyQualifiedName~AbortedBackupWithStalledUploads"`:

| Test | Before |
|---|---|
| `AbortedBackupTests.AbortedBackupWithStalledUploadsReturnsAsync(True)` (upload ignores the token) | fails: `The abort did not make the backup return within two minutes` |
| `AbortedBackupTests.AbortedBackupWithStalledUploadsReturnsAsync(False)` (upload observes the token) | passes before and after, in 0.2-0.3 s |

Red then green on Windows and on Linux (WSL). `TestCategory=Disruption`, the Drime/Filejump delete-retry
tests, `DeprecatedUploadOptionTests` and the restore abort/stop tests are green (61).

## Not covered

- The other awaits that a stop does not reach (a synchronous source-file read, a running SQLite
  statement) are unchanged; a backup stuck there still does not return. This PR addresses the backend
  call only, which is the one the dump showed and the one a test could pin down.
- The abandoned call keeps running until the destination gives up or the disposed backend makes it
  fail; the manager logs it as an active transfer at termination, as it already did for the one-second
  grace period.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
