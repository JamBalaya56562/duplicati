## What happens

`ServerApiIntegrationTests.RestoreFromAMissingDestinationReportsFailure_Async` failed on the macOS integration tests of #7397, which does not touch that path ([run 37601815845](https://github.com/duplicati/duplicati/actions/runs/37601815845/job/112727742747)): the restore from a missing destination was reported as `Completed` instead of `Failed`. Of the 42 runs of the test workflow since the test was added, this is the only one where the macOS integration tests failed.

When a task throws, `Runner.RunAsync` sets `TaskFinished` in its `finally` block. `QueueRunnerService.RunTaskAsync` stores the result only after that, when the exception reaches its `catch`. A client that asks for the task state in between gets the current task with `TaskFinished` set and no cached result, and `TaskQueueService.GetTaskInfo` reports that as `Completed`, because the missing result has no exception. `GetTaskQueue` does the same. The test polls every 250 ms and sometimes lands in that window.

The comment in `GetTaskInfo` says the result is cached by the time `TaskFinished` is set. That holds for the queue runner's own `TaskFinished`, but not for the one the runner sets first.

## The change

Until the result is cached, `GetTaskInfo` and `GetTaskQueue` report a current task as `Running`, without `TaskFinished`. Once it is cached, the outcome is reported as before.

## Checked

`FailedTaskIsNotReportedAsCompletedBeforeItsFailureIsStored_Async` runs the same restore from a missing destination, and reads the task state through `ITaskQueueService.GetTaskInfo` from the progress update that `Runner` sends right after it sets `TaskFinished`:

| | Before | After |
|---|---|---|
| State read in that window | `Completed` (2 of 2) | `Running` (3 of 3) |

In one of the two runs before the change, `RestoreFromAMissingDestinationReportsFailure_Async` also failed on Windows, with the same message as on macOS.

Two unit tests in `TaskQueueServiceTests` cover a current task that is finished without a cached result. I have not run them on the old code. `TaskQueueServiceTests` and both integration tests (14 tests) pass three times out of three on Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
