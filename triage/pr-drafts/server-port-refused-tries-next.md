Fixes #7330

## What happens

`WebServerLoader.TryRunServerAsync` tries the ports it is given in turn when one cannot be used. The tray icon relies on this and passes `8200,8300,8400,…`.

A port counted as unusable only when the error was one of these:

- a bare `SocketException` with `AddressAlreadyInUse` or `AccessDenied`;
- an `IOException` whose inner exception is `AddressInUseException`.

The default interface (`loopback`) binds with Kestrel's `ListenLocalhost`, which tries both IPv4 and IPv6. When neither can be bound, it reports the two failures together:

`IOException: Failed to bind to address http://localhost:8200` → `AggregateException` → `SocketException (10013)` ×2

That form was not recognized, so the server stopped instead of trying the next port.

Windows refuses the ports in the ranges it excludes for Hyper-V, WSL and Docker (`netsh interface ipv4 show excludedportrange protocol=tcp`). In #7330 both 8200 and 8300 are in such a range, and 8400 works when passed by hand. #6323 (for #6321) added the bare `AccessDenied` case, which covers an explicit interface but not the localhost default.

## The change

The check moves to `IsPortUnavailable`. It also accepts an `IOException` whose inner `AggregateException` holds only failures the server already moves on from (in use or refused).

## Red to green

`ServerApiIntegrationTests.ServerMovesOnFromAPortItIsNotAllowedToUse_Async` (new) starts the server through the same harness as the other integration tests, with the default `loopback` interface and two ports: a refused one, then a free one. It checks that the server listens on the second.

- **Windows**: the refused port is taken from a range the machine has excluded, read with `netsh` (listing needs no administrator rights). The test is ignored when there is none.
- **Linux**: port 1, which is refused to a user that is not root. The test is ignored when it can be bound.

| | Before | After |
|---|---|---|
| Windows (port 1032 in an excluded range) | **red**: the server stops with the exception above | green: listens on the next port |
| Linux (ext4, WSL, port 1) | **red**: the server does not start | green |

The harness takes an optional port list and interface; the other tests pass them as before. All of `ServerApiIntegrationTests` pass (9).

## Not covered

- A port held with exclusive use by another socket gives `AddressAlreadyInUse` on Windows, which was already handled. That is why the test uses an excluded range.
- Separately, while testing: at shutdown `QueueRunnerService.Terminate` can throw `ObjectDisposedException`, because `App.RunAsync` disposes the service container when the server stops. The error was logged in 1 of 3 runs both with and without this change, so it is unrelated and left as it is.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
