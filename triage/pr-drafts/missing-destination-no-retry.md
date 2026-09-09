## What happens

`BackendManager` retries every failed remote operation, with the retry delay in between. A destination folder that is not there (`FolderMissingException`) is retried the same way.

A restore from a destination that has been moved, or from a drive that is not connected, therefore lists it `number-of-retries` + 1 times, 10 seconds apart by default, before reporting the missing folder. Measured: about 51 seconds, with and without a local database. #4644 mentions this wait ("spent about 30-40 seconds 'verifying backend data' before realizing there was no backend data whatsoever").

Only a backup creates a missing destination folder: `Controller` turns `disable-autocreate-folder` on for every other operation. For those operations, waiting does not make the folder appear.

## The change

In `ExecuteWithRetryAsync`, an operation other than a backup gives up at once on a `FolderMissingException`, and reports the event as failed rather than retrying.

A backup keeps retrying, including when folder creation is turned off or fails. On a file destination, a network share that is briefly unreachable is also reported as a missing folder, and a backup is the operation that usually runs unattended.

## Red to green

`Duplicati/UnitTest/MissingDestinationRetryTests.cs` (new). It uses 3 retries 1 s apart and counts the list attempts in the log (`RetryList`), so the result does not depend on timing.

| Test | Before | After |
|---|---|---|
| A restore from a destination folder that has been moved away | **red**: listed 4 times | green: listed once, `FolderMissingException` |
| A backup to a missing folder with folder creation turned off | green: listed 4 times | green: still 4 (guard) |

Measured on Windows and on Linux (ext4, WSL) with the same results. Related tests pass (18: destination auto-create and permission tests, Tahoe delete status, the restore abort and stop tests).

## Not covered

- `LightWeightBackendManager` has its own copy of the retry loop and is unchanged.
- A first backup that fails this way leaves its database open after the operation. That is fixed separately in #7366, so the guard test uses a database of its own. Once both are merged, the test can go back to the shared database.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
