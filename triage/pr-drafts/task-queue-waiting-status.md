## What happens

`GET /api/v1/tasks` lists every task in the queue as `"Status": "Running"`, including the ones that have not
started. `GET /api/v1/task/{id}` answers `"Waiting"` for the same task, so the two endpoints disagree.

### Why

`TaskQueueService.GetTaskQueue` derives the status from `TaskFinished` alone
([TaskQueueService.cs:88-93](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/WebserverCore/Services/TaskQueueService.cs#L88-L93)):
no timestamp means "Running". A queued task has no `TaskFinished` either - it has not even started - and so
it is listed as running. `GetTaskInfo` in the same class goes by position: the current task is running, a task
in the queue is waiting.

## The change

`GetTaskQueue` goes by position too: the task at the front of the listing (the current one) is `Running`, the
tasks behind it are `Waiting`, and a task with a `TaskFinished` timestamp is reported from its cached result as
`Completed` or `Failed`, as before. The other fields are unchanged.

Extends the test file added by #7323 (merged); this PR is the single commit on top of master.

## Red to green

`--filter "FullyQualifiedName~GetTaskQueue_"`:

| Test | Before |
|---|---|
| `GetTaskQueue_QueuedTasksBehindTheRunningOne_ReportWaiting` (running task plus two queued ones) | `Expected: "Waiting" But was: "Running"` |
| `GetTaskQueue_NoCurrentTask_ReportsEveryQueuedTaskWaiting` | `Expected: "Waiting" But was: "Running"` |
| `GetTaskQueue_CurrentTaskThatHasFinished_ReportsTheCachedOutcome(True/False)` | passes before and after |

Green after the change on Windows and on Linux (WSL). `TestCategory=TaskQueue` and `FolderStatusServiceTests` are green.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
