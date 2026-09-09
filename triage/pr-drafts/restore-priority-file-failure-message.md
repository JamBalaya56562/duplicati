Builds on `fix/restore-copy-failure-takes-lock`, which is stacked on #7364 and the branches after it. Open it after those are merged, rebased on master.

## What happens

A priority file (`IRestoreDestinationProvider.GetPriorityFiles`, for instance the geometry and partition information of a disk image) has to be restored before the other files. When one fails, the priority barrier is faulted with its error, and the file processors waiting on the barrier end the restore with that error.

The user then sees only that file's error. For instance, `UnauthorizedAccessException: Access to the path '...' is denied.` does not say that the rest of the restore was stopped because of it.

Stopping the restore is intended ([`c780367c5`](https://github.com/duplicati/duplicati/commit/c780367c5d186846b12443142f8d7374b413df7c) documents it: fail with the real error rather than stall), and restoring the data without the layout is not safe. So only the message changes.

## The change

`FaultPriorityBarrierIfPriorityFile` faults the barrier with a `UserInformationException` (`RestorePriorityFileFailed`). Its message says that the restore was stopped because the named file, which has to be restored before the other files, could not be restored, followed by the file's own error. The file's error is kept as the inner exception.

## Red to green

`AFailedPriorityFileStopsTheRestoreWithAnExplanation` (new, in `RestoreFileFailureTests`): a callback module makes an empty file a priority file, and a folder is in its way. The test checks the error the restore ends with: its type, its help ID, the file path and the file's own error in the message, and the inner exception.

| | Before | After |
|---|---|---|
| The error the restore ends with | **red**: the raw `UnauthorizedAccessException` | green |

Measured on Windows and on Linux (ext4, WSL). The class (10 tests) and the related restore tests (29 in total with the class) pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
