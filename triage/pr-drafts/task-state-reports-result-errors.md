Fixes #4644
Fixes #4051

## What happens

The web UI shows the restore as successful when the task state for it says `Completed` with no `ErrorMessage` (`restore-progress.component.ts` in ngclient: `task.Status === 'Completed' && task.ErrorMessage == null`).

The server only fills in `ErrorMessage` when the task threw. `QueueRunnerService` discarded the results `Runner.RunAsync` returned, so a task that finished normally but whose results hold errors was reported as a clean `Completed`.

A restore does that when it cannot restore a file. For instance, when a file in the way cannot be read, the restore logs the errors, restores nothing, and returns normally. The UI then shows the success mark with an error notification next to it, which is what #4644 and #4051 describe.

The scenario both issues started from, a destination that is not there, already throws today and is reported as `Failed`. A test for that is added below, so the two issues are covered on both paths.

## The change

- `QueueRunnerService` keeps a message for a result whose `ParsedResult` is `Error` or `Fatal`: the error itself when there is one, otherwise `Got N error(s)`, the same as the notification `Runner` registers for the result.
- `TaskQueueService` reports it as `ErrorMessage` when there is no exception. This applies to both `GetTaskInfo` and `GetTaskQueue`.
- `Status` stays `Completed`. Clients use `Completed` or `Failed` to see that the task is done (ngclient's `server-state.service.ts`), so no new status value is introduced. Successful tasks and tasks with only warnings report no `ErrorMessage`, as before.

No change is needed in ngclient: the restore page already checks `ErrorMessage`.

## Red to green

Two tests in `ServerApiIntegrationTests`. Each starts the server, creates and runs a backup through the API, then restores through `/api/v1/backup/{id}/restore` and reads `/api/v1/task/{id}`.

| Test | Before | After |
|---|---|---|
| `RestoreWithErrorsReportsAnErrorMessage_Async`: a file in the way of the restore cannot be read (held open without sharing on Windows, no permissions elsewhere) | **red**: `Completed`, `ErrorMessage` null | green: `Completed` with an error message |
| `RestoreFromAMissingDestinationReportsFailure_Async`: the destination folder has been moved away | green: `Failed` with the reason | green |

The first test was measured red and green on Windows and on Linux (ext4, WSL). On Linux it is skipped when the file can still be read, for instance as root. The second one guards the path that already works and was run on Windows.

All of `ServerApiIntegrationTests` (including the existing checks that a successful backup and restore report no `ErrorMessage`) and `TaskQueueServiceTests` pass: 20 tests.

## Not covered

- `GetTaskQueue` gets the same one-line change, but only `GetTaskInfo` is exercised by the tests.
- Other ngclient pages decide on `Status` alone, so they do not change. For instance, the database repair started from the restore page treats a `Completed` repair with errors as successful. That would be a change in ngclient.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
