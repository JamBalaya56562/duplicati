## What happens

`GET /api/v1/task/{id}` can answer `"Status": "Running"` for a task that has already finished - with
its `TaskFinished` timestamp set and without its outcome.

Seen while looking into #6597 with an in-process server and the restore-from-files sequence of the
web UI (temporary backup, `list-filesets`, `repairupdate`, poll the task, `list-folder`), with a repair
that fails on purpose (wrong passphrase):

```
GET /api/v1/task/{id}  ->  Status=Running  TaskStarted=...13:14:47.556  TaskFinished=...13:14:47.898  ErrorMessage=
POST /api/v2/backup/list-folder  ->  {"Success":false,"Error":"No backup at the specified date","StatusCode":"NoBackupAtDate"}
```

### Why

`QueueRunnerService.RunTaskAsync` stamps `TaskFinished` and only then clears the current task
([QueueRunnerService.cs:175-183](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/WebserverCore/Services/QueueRunnerService.cs#L175-L183)),
so for a moment a task is both current and finished. `TaskQueueService.GetTaskInfo` answers for the
current task unconditionally with `"Running"`
([TaskQueueService.cs:35-41](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/WebserverCore/Services/TaskQueueService.cs#L35-L41)),
while `GetTaskQueue` in the same class reports that same task from the cached result as `Completed` or
`Failed` with its `ErrorMessage`
([:63-83](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/WebserverCore/Services/TaskQueueService.cs#L63-L83)).
The cached result exists at that point: `AddTaskResult` runs before the `finally` on both the success
and the failure path.

The web UI's `waitForTaskToComplete` stops waiting as soon as `TaskFinished` is set. If it lands in this
window it never sees `Failed` nor the message, proceeds to `list-folder`, and the user gets
"No backup at the specified date" instead of the repair error. (The UI is being changed separately to
look at the status; the server should not report a finished task as running in the first place.)

## The change

`GetTaskInfo` reports a current task that carries a `TaskFinished` timestamp the way `GetTaskQueue`
does: status from the cached result (`Completed` / `Failed`), with `ErrorMessage` and `Exception`. A
current task without the timestamp is still `Running`; queued and already-cleared tasks are answered
as before. The runner's ordering is left alone.

## Red to green

`--filter "FullyQualifiedName~TaskQueueServiceTests"` against a mocked `IQueueRunnerService`:

| Test | Before |
|---|---|
| `GetTaskInfo_CurrentTaskThatHasFinished_ReportsTheCachedOutcome(True)` | fails: `Expected: "Failed" But was: "Running"`, no `ErrorMessage` |
| `GetTaskInfo_CurrentTaskThatHasFinished_ReportsTheCachedOutcome(False)` | fails: `Expected: "Completed" But was: "Running"` |
| `GetTaskInfo_CurrentTaskStillRunning_ReportsRunning`, `GetTaskInfo_QueuedTask_ReportsWaiting`, `GetTaskInfo_FinishedTaskNoLongerCurrent_ReportsFromTheCache(True/False)` | pass before and after |

`FolderStatusServiceTests` (the other consumer of the same mocks) and the integration test that polls
this endpoint, `ServerApiIntegrationTests.ServerRepairUpdateListsRootPaths_Async`, are green.

## Observations, not changed here

- The cached result's `TaskFinished` is `DateTime.Now` (local) while `task.TaskFinished` is
  `DateTime.UtcNow` (`QueueRunnerService.cs:159, :168, :177`); both serialize with their offset.
- `GetTaskQueue` reports a queued task that has not started as `Running` (its `TaskFinished` is null).
- The restore-from-files sequence itself, run 54 times in-process the way the UI runs it, did not
  reproduce the race described in #6597 on current master; the repair and the folder listing are
  serialized by the database lock tracker since f690297d1.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
