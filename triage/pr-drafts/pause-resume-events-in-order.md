## What happens

The server pauses and resumes the backup queue from the state change events of `LiveControls`. It uses the state that each event carries (`Program.LiveControl_StateChanged`).

`Pause` sends its event while it holds the lock. Three other paths sent theirs after releasing the lock:

- `Resume`
- the pause taken on suspend (`OnSuspend` → `SetPauseMode`)
- a pause renewed while already paused

So a pause and a resume on two threads could be handled in the reverse order. The state ended up running, but the queue was told "paused" last, and stayed paused because nothing changed the state again.

Waking up did not fix it either: `OnResume` found the state already running, so it had nothing to resume.

This needs a resume at the moment the machine suspends or a pause is renewed. The resume can come from the user, or from a timed pause running out.

## The change

All four paths now send their event while holding the lock, as `Pause` already did. Events are handled in the order the state changed, and a resume that comes in meanwhile waits for the pause's event to be handled first.

## Checked

`LiveControlsEventOrderTests` pauses on one thread and holds it just before its event is handled, then resumes on another thread:

| Test | Before | After |
|---|---|---|
| `TheQueueIsToldTheLastStateWhenASuspendAndAResumeCross` | fails: state running, queue told paused | passes |
| `TheQueueIsToldTheLastStateWhenARenewedPauseAndAResumeCross` | fails: state running, queue told paused | passes |
| `TheQueueIsToldTheLastStateWhenAPauseAndAResumeCross` | passes | passes |

`LiveControlsLoggingTests` and `ServerApiIntegrationTests` also pass.

#7396, now in master, touches the same file: it serialises the suspend and resume handlers. On top of it, the three tests above pass, together with its `SuspendResumeStateTests` and `LiveControlsLoggingTests` (6 tests, Windows).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
