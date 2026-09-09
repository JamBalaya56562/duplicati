# WithTimeout: report only its own timeout as a TimeoutException

Branch: `fix/withtimeout-cancel-vs-timeout` (commit [5d2af95f250712bb325c1d71efd6f23c955c0831](https://github.com/JamBalaya56562/duplicati/commit/5d2af95f250712bb325c1d71efd6f23c955c0831)), based on master 7cdde158.

## Problem

`Utility.WithTimeout` runs the call with a token linked to the caller's token, and that token is cancelled after the timeout. Each of the four overloads caught only `TaskCanceledException` and turned it into a `TimeoutException` whenever the linked token was cancelled. This had two effects:

- **A timeout could come out as a cancellation.** When the wrapped call reacts to the timeout with a plain `OperationCanceledException` (for example `ct.ThrowIfCancellationRequested()`, or a library that throws it), the exception passed through unchanged. Callers that treat an `OperationCanceledException` as the user stopping the operation, such as several `catch (OperationCanceledException)` blocks in restore and test, could then mistake a timeout for a stop. For the synchronous overloads, awaiting the `Task.Run` task also rethrows the delegate's own `OperationCanceledException`, so they had the same problem.
- **A cancellation by the caller came out as a timeout.** Because the timeout token is linked to the caller's token, it is also cancelled when the caller cancels, so a user stop was reported as "The operation has timed out." For example, `proprietary/Office365/APIHelper.cs` catches `TimeoutException` as a transport error, so a stop went into its transport-error path.

`BackendManager` decides between retrying and stopping by looking at its own tokens, not at the exception type, so its retry logic is not affected either way.

## Change

All four overloads now use `catch (OperationCanceledException) when (cts.IsCancellationRequested && !token.IsCancellationRequested)` and throw a `TimeoutException` there. That covers both `TaskCanceledException` and plain `OperationCanceledException`. A cancellation by the caller is rethrown unchanged.

## Testing

New unit tests in `WithTimeoutCancellationTests`:

- `AsyncCallThatThrowsOperationCanceledTimesOut`, `AsyncCallWithResultThatThrowsOperationCanceledTimesOut`, `SyncCallThatThrowsOperationCanceledTimesOut`, `SyncCallWithResultThatThrowsOperationCanceledTimesOut`: the call polls the token and throws `OperationCanceledException`, and the result must be a `TimeoutException`.
- `CallerCancellationOf{An,AnAsyncCallWithResult,ASync,ASyncCallWithResult}...IsNotATimeout`: the caller's token is cancelled before the timeout, and the result must be an `OperationCanceledException`.

On master, 6 of the 8 tests fail. The two synchronous caller-cancellation tests already pass on master, because the delegate's own `OperationCanceledException` is rethrown unchanged. On this branch, all 8 pass.

This branch merges cleanly with `fix/smb-timeout-aborts`, which also edits the synchronous overloads. I checked this with a temporary `jj new` merge, and `WithTimeoutCancellationTests` and `SMBTimeoutTests` (12 tests) all pass on the merged tree.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
