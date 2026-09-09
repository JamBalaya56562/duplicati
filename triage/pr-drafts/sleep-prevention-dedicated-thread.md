## What happens

With `--allow-sleep=false` (the default), an operation on Windows keeps the system awake through `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)`. That request belongs to the thread that makes it, and it holds until the same thread withdraws it or ends.

`ProcessController.StartSleepPrevention` renewed the request every 10 seconds from a `Task.Run` loop, so it was made on thread pool threads. `StopSleepPrevention` withdrew it with `SetThreadExecutionState(ES_CONTINUOUS)` on the thread that disposed the controller, which only clears that thread's own request. The pool threads live on after the operation, and so does their request: the system stays awake after every backup has finished.

Measured with `CallNtPowerInformation(SystemExecutionState)`, which reads what the system is honouring from every process and needs no administrator rights (unlike `powercfg /requests`): `0x0` before the operation, `0x1` while it runs, and still `0x1` 20 seconds after the controller was disposed, in 3 of 3 rounds.

## The change

A thread of its own makes the request once (`ES_CONTINUOUS` keeps it without renewal), waits until the operation stops, and withdraws it before it ends. Stopping signals the thread and waits up to 5 seconds for it. Starting again stops a previous thread first.

macOS (`caffeinate`) and Linux (inhibitor locks) are unchanged.

## Red to green

`Duplicati/UnitTest/SleepPreventionTests.cs` (new, Windows only; ignored elsewhere, and ignored when something else already keeps the system awake) runs a `ProcessController` with `allow-sleep=false` twice. Each time it waits 12 seconds, long enough for the old loop to renew the request from another thread, checks that the system is kept awake, disposes the controller, and then allows 5 seconds for the system to be allowed to sleep again.

| | Before | After |
|---|---|---|
| `TheSystemMaySleepAgainAfterAnOperation` | **red**: "The system is still kept awake after the operation ended" | green |

Operations reach this through `Controller` (`using (new ProcessController(m_options))`). The other unit tests run with `allow-sleep=true`, so they do not touch this path.

Fixes #6837

🤖 Generated with [Claude Code](https://claude.com/claude-code)
