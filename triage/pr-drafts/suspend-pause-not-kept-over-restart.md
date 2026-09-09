Fixes #6759

## What happens

When the machine goes to sleep, `LiveControls.OnSuspend` pauses the server until it wakes up. That pause has no expiration of its own, so the state change event carries a `WaitTimeExpiration` of zero, and `Program.LiveControl_StateChanged` stores it as `PausedUntil`. Zero is also what a pause the user sets with no end is stored as.

If the server is restarted before the machine wakes up, for example because it was shut down while it slept, `LiveControls.Init` reads the stored zero as a pause with no end. The server stays paused, and no scheduled backup runs until the user clicks "Resume". The restart stores the zero again, so it also survives later restarts.

## The change

- `LiveControlEvent` gets `PausedForSuspend`, which is set only on the event that `OnSuspend` sends when it pauses the server.
- `LiveControl_StateChanged` does not store such a pause; `PausedUntil` stays empty, as when the server is running. After a restart, the server starts as it normally would.
- A pause the user sets, with or without an end, is stored as before. So is the pause after the machine wakes up.

## Checked

`SuspendResumeStateTests.RestartWhileSuspended_Async` starts the server, calls `OnSuspend` as the power mode provider would, stops the server without a resume, and starts it again with the same data folder:

| | Before | After |
|---|---|---|
| State after the restart | Paused, with no end (`0001-01-01T00:00:00Z`) | Running, passes 3 times out of 3 |

`SuspendResumeStateTests` and `LiveControlsEventOrderTests` (6 tests) pass three times out of three on Windows.

One comment in the issue describes a server that pauses after a day or two on a machine that does not sleep. I have not reproduced that case, and this change is not shown to cover it.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
