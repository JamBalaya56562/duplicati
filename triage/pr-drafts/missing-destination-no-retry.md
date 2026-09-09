## What happens

Every remote operation is retried, with the retry delay in between. A destination folder that is not there was retried the same way, so a restore from a destination that had been moved or disconnected took the whole retry budget, about 50 seconds by default, before it said so. #4644 mentions the wait.

## The change

The restore lists the destination once, without retries, before it starts, and stops at once if the folder is not there:

- Only a missing folder (`FolderMissingException`) stops the restore here. Other errors are logged and left to the restore, which retries them as before.
- A folder that goes missing while the restore runs, such as a network share that is briefly unreachable, is still retried.
- The check is skipped with `--no-backend-verification`, as the rest of the pre-restore verification is.
- It only reads the first entry of the listing, and it is done by the restore started through the `Controller`. The restore test (`RestoreTestHandler`) is unchanged.

The first version of this PR stopped retrying a missing folder in every operation but backup, which also gave up on a share that drops out during a restore. That part is gone: the retries in `BackendManager` are unchanged.

## Checked

`MissingDestinationRetryTests`, Windows:

| | Before | After |
|---|---|---|
| `ARestoreFromAMissingDestinationFailsAtOnce`: the destination is moved away | **red**: retried 4 times | green: no retry, `FolderMissingException` |
| `ARestoreWithoutBackendVerificationStillRetries`: the same with `--no-backend-verification` | green | green |

Restoring 200 files through a directory junction that is removed and put back, with a 500 KB/s download throttle:

| The destination is gone | master | This PR |
|---|---|---|
| from the start, back after 15 s | retried, all 200 files restored in 42 s | failed after 0.7 s with `FolderMissingException` |
| 3 s into the restore, back after 15 s | retried, all 200 files restored in 31 s | retried, all 200 files restored in 33 s |
| from the start, back after 75 s | failed after 51 s | failed after 0.6 s |

A network path that cannot be reached is reported by the file backend as a missing folder too: an unknown host, an unknown share, an unknown WSL distribution and an unmapped drive letter all gave `FolderMissingException`, in 0 to 70 ms.

`RestoreHandlerTests`, `ServerApiIntegrationTests` (including `RestoreFromAMissingDestinationReportsFailure_Async` from #7365) and `RestoreFileFailureTests` also pass, 48 tests with the new ones (Windows).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
