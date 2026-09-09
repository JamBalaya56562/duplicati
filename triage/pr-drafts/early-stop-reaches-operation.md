## What happens

When the user presses Stop, or Abort, for a task that has started but is still being set up, the request is dropped:

- The server passes it to the task's controller, and the task has no controller yet.
- Or the controller passes it to the operation's task control, and there is none yet.

The operation then runs to the end although the user asked it to stop. The web UI shows the Stop button for the task during this time, and shows the task as stopping once the button is pressed.

Measured against a real server through its API (`/api/v1/backup/{id}/run`, then `/api/v1/task/{id}/abort`), backing up 200 files of 256 KB:

| Run | Request | Result |
|---|---|---|
| First run after the server started | abort 223 to 360 ms after the start (3 runs, each in a new process) | dropped every time, the backup backed up all 200 files |
| First run after the server started | stop 149 ms after the start | dropped, the backup backed up all 200 files |
| First run after the server started | abort 811 ms and 1349 ms after the start | carried out |
| Later runs | stop or abort 9 to 121 ms after the start | carried out |

The first run after the server starts is the one that hits this, for example a scheduled backup soon after the machine starts.

## The change

Both places now keep such a request, and pass it on once there is something to take it:

- A task that has started keeps it until it gets its controller, and then passes it on. A queued task is left as it was, so a request for a task that has not started still does nothing.
- A controller keeps it until its first operation starts, and applies it then. A request that comes between two operations on the same controller still does nothing, so it is not carried to the next one.

Each keeps the request and its target under one lock, so a request cannot slip in between the check and the handover.

## Why this relies on #7366

An abort that is carried out this early lands while the backup opens its local database. Opening it then fails with the cancellation. Before #7366 the connection was not closed, and the database file stayed open until the process exited; I saw this while writing the tests, before #7366 was merged. With #7366, now on master, it can be opened exclusively again once the backup has returned.

## Checked

`EarlyStopRequestTests`:

| Test | Before (master with #7366) | After |
|---|---|---|
| `AnAbortBeforeTheBackupStartsAbortsIt` | fails, the backup completes | passes |
| `AStopBeforeTheBackupStartsStopsIt` | fails, not interrupted | passes, interrupted |
| `AStartedTaskPassesAnEarlyRequestToItsController` (abort, stop) | fails, the controller gets nothing | passes |
| `AnAbortBetweenTwoOperationsIsNotCarriedToTheNext` | passes | passes |
| `AQueuedTaskKeepsIgnoringARequest` | passes | passes |

The results are the same on Windows (3 runs) and on Linux.

Against the real server, on the first run after the server started:

- An abort 143 to 168 ms after the start now stops the backup within 0.7 s, with nothing uploaded (3 of 3).
- A stop 155 to 173 ms after the start now ends it as interrupted within 1.2 s, with no files examined (3 of 3).

`DisruptionTests`, `AbortedBackupTests`, `ServerApiIntegrationTests`, `TaskQueueServiceTests` and `FailedOperationDatabaseTests` also pass (63 tests, Windows).

## Not changed

- An abort carried out this early is reported as a failed task, for example "A task was canceled.". That is how the task queue reports an abort that surfaces as an exception, and aborts later in a run are reported the same way at some points. Before this change such an abort was dropped, so the failed status will be seen more often.
- A stop or abort for a queued task still does nothing.
- A stop or abort that cancels the wait for the database lock still fails the task.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
