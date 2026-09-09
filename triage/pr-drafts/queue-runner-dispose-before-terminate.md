## What happens

At shutdown, `Program.Main` stops the web server (`ShutdownModernWebserver`) and then terminates the queue runner (`queueRunner.Terminate(true)`).

Stopping the web server ends `App.RunAsync()` (started in `DuplicatiWebserver.StartAsync`), which disposes the service container, including the singleton `QueueRunnerService`, whose `Dispose` disposes its termination token source. Depending on timing, that happens before `Terminate`. `Terminate` then calls `Cancel()` on a disposed source, and the shutdown logs:

`ObjectDisposedException: The CancellationTokenSource has been disposed.` at `QueueRunnerService.Terminate` ← `Program.Main`

Seen in 2 of 6 server starts and stops in the integration tests, with and without other changes. It is logged by the teardown loop and does not stop the rest of the shutdown.

## The change

- `Terminate` and `Dispose` both cancel through a helper that skips a source that is already disposed.
- `Dispose` also marks the queue as terminated and cancels the waiting tasks, as `Terminate` does. When it comes first, nothing is left waiting on a source that can no longer be cancelled.

## Red to green

`Duplicati/UnitTest/QueueRunnerServiceShutdownTests.cs` (new) calls the two in both orders. Neither uses the service's dependencies, so they are passed as `null`.

| Test | Before | After |
|---|---|---|
| Disposed, then terminated (the shutdown order that fails) | **red**: `ObjectDisposedException` | green |
| Terminated, then disposed | green | green (guard) |

`TaskQueueServiceTests` pass. The race itself does not reproduce on demand: starting and stopping the server 6 times showed the error 0 times before and after this change, and 2 of 6 times in earlier runs.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
