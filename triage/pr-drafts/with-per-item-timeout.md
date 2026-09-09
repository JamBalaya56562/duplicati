# Utility: time only the wait for each item in WithPerItemTimeout

Branch: `fix/with-per-item-timeout` (commit [7206a0469e050341c433f01b47b5aed16ce594f9](https://github.com/JamBalaya56562/duplicati/commit/7206a0469e050341c433f01b47b5aed16ce594f9)), based on master 7cdde158.

## Background

`Utility.WithPerItemTimeout` was added in 8aee23c27 ("Updated Minio to 6.0.4") for the MinIO listing. When MinIO was reverted to 6.0.0 for #6489 in 0497de7e9, that listing stopped using it. Nothing in the repository calls it today, so this change has no effect on users now. It matters if the helper is used again, for example when MinIO is upgraded again and `ListObjectsEnumAsync` comes back. `fix/s3-minio-list-timeout` deliberately does not use the helper because of the problems below.

## Problems

- **The caller's time counted toward the timeout.** The timer was reset in a `finally` block that runs only when the caller asks for the next item. If the caller spent longer on an item than the timeout, the next step threw, even though the source was not slow.
- **A timeout came out as a cancellation.** That `finally` block threw `OperationCanceledException`, or the caller saw a canceled task. A `TimeoutException` was thrown only when the timer fired while the code was waiting on `Task.WhenAny`.
- **A cancellation by the caller came out as an `AggregateException`**, from `moveNextTask.Result`.

## Change

- Each wait for the next item now has its own token source, linked to the caller's token and set to cancel after the timeout. The wait is `MoveNextAsync().AsTask().WaitAsync(...)`, so only the wait for the source is timed.
- A timeout throws `TimeoutException`. A cancellation by the caller is rethrown as an `OperationCanceledException`.
- On a timeout or an early stop, the source's token is cancelled. The pending `MoveNextAsync` then gets one more timeout period to finish before the enumerator is disposed. An async iterator cannot be disposed while a `MoveNextAsync` is still running (it throws `NotSupportedException`), so that exception would otherwise hide the timeout. A source that ignores the token is left undisposed rather than hanging the caller.
- The enumerator is created directly. It used to be created inside `WithTimeout`'s synchronous overload, which only wrapped the call to `GetAsyncEnumerator`, and that call returns at once.

## Testing

New unit tests in `WithPerItemTimeoutTests`:

- `TimeSpentOnAnItemDoesNotCount`: the source yields 3 items at once, and the caller spends 1 s on each with a 500 ms timeout. All 3 items must arrive.
- `SlowSourceTimesOut`: the source waits 30 s per item. The result must be a `TimeoutException`.
- `CallerCancellationIsNotATimeout`: the caller cancels after 200 ms. The result must be an `OperationCanceledException`.

On master, all 3 tests fail: `AggregateException (A task was canceled)`, `OperationCanceledException`, and `AggregateException`. On this branch, all 3 pass. Without the bounded wait before dispose, two of them failed with `NotSupportedException`.

This branch merges cleanly with `fix/withtimeout-cancel-vs-timeout` and `fix/smb-timeout-aborts`, which also edit `Utility.cs`. I checked this with a temporary three-way `jj new` merge, and ran the tests of all three branches on the merged tree.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
