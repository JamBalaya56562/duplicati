## What happens

When the machine goes to sleep, `LiveControls.OnSuspend` pauses the server and marks the pause as caused by the suspend (`m_pausedForSuspend`), and `OnResume` resumes only a pause marked that way.

`OnSuspend` sets the mark after `SetPauseMode()` returns, and `SetPauseMode()` runs the state change handler (`Program.LiveControl_StateChanged`): it pauses the queue and the running task and saves `PausedUntil` in the server database. If the machine is suspended before that has finished, the resume notification can arrive in between. `OnResume` then finds no pause caused by the suspend and does nothing, the suspend handling finishes afterwards, and the server stays paused until someone resumes it. The tray icon shows that pause, as it should.

## The change

`OnSuspend` and `OnResume` take a lock of their own, so they run one at a time. A resume that arrives while the suspend is still being handled waits for it and then resumes. The existing `m_lock` is not used for this, as the state change handler is deliberately called outside it.

## Red to green

`Duplicati/UnitTest/SuspendResumeStateTests.cs` (new) starts a real server, follows its state with long polls from the last seen event as the tray icon does, and calls the suspend and resume handlers the power mode provider would call.

| Test | Before | After |
|---|---|---|
| `SuspendThenResume_Async` (one after the other) | green | green (guard) |
| `ResumeWhileSuspendIsStillBeingHandled_Async` (the state change handler for the suspend is held until the resume has been called) | **red**: the server and the follower both stay `Paused` | green: both `Running` |

Measured on Windows and on Linux (WSL), with the same test.

In Debug builds the test server keeps its data next to the test assembly, shared with the other server tests, so the test starts by resuming the server and resumes it again when it ends.

## Relation to #6867

#6867 reports that after waking from sleep on Windows 11 the tray icon keeps showing the paused state until the pause is toggled. This change fixes one order of events that leaves the server paused after a wake-up. Whether it is the order that the report runs into has not been confirmed on a real suspend: the resume must arrive before the suspend has been handled, which depends on the timing of the machine (Modern Standby freezes desktop processes shortly after the suspend notification). The report also mentions that the main UI showed the backup as running, which this order alone does not explain.

Related to #6867

🤖 Generated with [Claude Code](https://claude.com/claude-code)
