Fixes #6

## Changes

- `WrappingStream` no longer overrides `Close()`. `Stream.Close()` calls `Dispose(true)`, and `Dispose(bool)` already disposes the base stream only when `DisposeBaseStream` is set, so `disposeBaseStream: false` now keeps the base stream open for `Dispose()`, `Close()` and `using`.
- `WrappingStream.DisposeAsync()` runs the synchronous cleanup once (so the `Dispose(bool)` of a derived stream, such as the timers of `TimeoutObservingStream`, runs once), and then disposes the base stream asynchronously only when `DisposeBaseStream` is set. It used to dispose the base stream and then call `base.DisposeAsync()`, which went through `Close()` and disposed it again.
- `ThrottleEnabledStream` no longer overrides `DisposeAsync()`: its `Dispose(bool)` already unregisters the transfers, and the override made them unregister twice.

## Testing

New `Tests/DisposeTests.cs` (35 cases): for `TimeoutObservingStream`, `ThrottleEnabledStream` and a test subclass of `WrappingStream` and of `WrappingAsyncStream`, disposed with `Dispose()`, `Close()`, `DisposeAsync()`, `using` and `await using`, with `disposeBaseStream` true and false:

- the base stream is disposed exactly once when `disposeBaseStream` is true, and not at all (still readable) when it is false
- the cleanup of the wrapping stream (`Dispose(bool)`) runs exactly once

Before the change all 35 cases fail (the base stream is disposed with `false`, two or three times with `true`, and the cleanup runs more than once); after it they pass. The whole test project passes (70/70) on Windows with .NET 10 rolling forward the net8.0 tests.

### QuickTest on Windows, and #7

`QuickTest`'s timeout scenario sometimes fails on Windows on `main` too: its 3 s read timer starts before the connection, and connecting to `localhost` spends about two seconds on a refused IPv6 attempt. #7 fixes that separately, and this PR does not depend on it. Runs on Windows 11, interleaved (the time from setting `ReadTimeout` to the first read comes from the runs of builds with logging added):

| Build | Failed runs | Time to first read |
| --- | --- | --- |
| `main` | 1 of 51 | 2156–2453 ms |
| this branch | 4 of 55 | 2187–2765 ms |
| #7 | 0 of 17 | — |
| this branch + #7 | 0 of 17 | 125–797 ms |

Every failure, on `main` and on this branch, was the read timer firing before the first read completed (on `main` while the request was still waiting for its connection). No stream is disposed before the first read on either build. The difference between 4 of 55 and 1 of 51 is within chance (Fisher's exact test, p ≈ 0.2).

## Checked in Duplicati

Duplicati was built against this branch packed as a local `1.0.6-local` package, with a test backend that wraps the caller's stream the way the SSH backend does (`ObserveWriteTimeout(..., false)` / `ObserveReadTimeout(..., false)` in a `using` statement):

| Scenario | 1.0.5 | This branch |
| --- | --- | --- |
| Remote synchronization with `--verify-get-after-put` | exit code 3 | exit code 0 |
| Retry of a failed get (`LightWeightBackendManager`) | fails after 3 attempts | passes |
| Retry of a failed put | fails after 3 attempts | passes |
| Rename fallback (`prevent-backend-rename`) | fails | passes |
| `Position` after `GetAsync` | `ObjectDisposedException` | passes |
| Backup, test of all volumes and restore through `BackendManager` | passes | passes |

This is the cause behind duplicati/duplicati#6806, which duplicati/duplicati#6809 worked around.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
