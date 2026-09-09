# Stop a restore of many small files from keeping memory for every block

Fixes #7538

A restore of many small files keeps two objects alive for every block it requests, long after the block has arrived. The memory of the restore therefore grows with the number of files.

**1. The deadlock timer of each block request.** `BlockManager.SleepableDictionary.GetAsync` watches each request with `Task.WhenAny(Task.Delay(timeout, tcs1.Token), new_tcs.Task)`. When the block arrives first, `tcs1` is disposed by its `using`, but not cancelled. Disposing a token source does not stop a delay, so its timer stays alive for the whole timeout: `DeadlockTimer.MaxProcessingTime * 2`, which is 10 minutes for 50 MB volumes. The restore therefore holds a timer, a delay promise, a token source and a registration for every block requested in the last 10 minutes.

**2. The channel reads of the volume manager.** `VolumeManager.ReadFromEither` reads each request with `channel.ReadAsync(token)`, using the token of the restore. The CoCoL read registers a callback on that token and does not remove it when the read completes. The token of the restore therefore holds a callback, an `Action` and a captured `ExecutionContext` for every volume request, until the restore ends.

The fixes:

- Cancel the delay as soon as the block arrives.
- Give each channel read a token of its own, linked to the token of the restore, and dispose it when the read completes.

## Measurements

These are restores of 200,000 small files (200 to 2,000 bytes each) on current master (240c2bc7fe6e), Release CLI, Linux. The heap was read with `dotnet-gcdump` during the restore.

| | master | first fix only (`BlockManager`) | both fixes |
|---|---|---|---|
| peak RSS | 1,083 MB | 919 to 925 MB | 837 to 843 MB |
| RSS while files are restored | grows about 1.2 MB/s | grows about 0.6 MB/s | flat (814 MB at 44 s, 843 MB at the end) |
| `TimerQueueTimer` / `DelayPromiseWithCancellation` after 120 s | 309,168 each | not in the top of the heap | not in the top of the heap |
| `CancellationTokenSource+CallbackNode` after 120 s | 583,235 | 228,814 | not in the top of the heap |

The run time is not changed by the fix. Two back-to-back runs of each build took 379 s and 454 s with the first fix only, and 321 s and 363 s with both.

For the callbacks, a full dump (`dotnet-dump`, `gcroot` and `dumpdelegate`) showed what holds them. The `CallbackNode`s are chained to the `CancellationTokenSource` of the `TaskControl` of `RestoreResults`, and each callback is `CoCoL.Channel<T>.<ReadAsync>b__30_1`.

The per-file growth is about 1.2 KB, two blocks per file. For a backup of a few million small files, that is several GB, which matches the 14 to 18 GB in the report.

The rest of the memory is the file list (`FileRequest`) and the open volumes. With the default `restore-volume-cache-hint` there is no limit, so the central directories (`ZipArchiveEntry`) of every volume stay in memory. Both are loaded on purpose and are not changed here.

## Testing

- New `RestoreBlockRequestTimerTests.ARestoreDoesNotKeepSomethingForEveryBlockAsync`. It restores 2,000 small files, then counts the timers still running (`Timer.ActiveCount`) and the callbacks still registered on the token of the restore.
  - Without the `BlockManager` change: `3951 timers were left running after restoring 2000 files`.
  - Without the `VolumeManager` change: `3828 callbacks were left registered on the token of the restore after restoring 2000 files`.
  - With both: passes.
- `RestoreAllFilesTests`, `RestoreFileFailureTests`, `RestoreHandlerTests`, `RestoreDryRunVerificationTests`, `RestoreTestHandlerTests`, `RestoreMissingFolderTests`, `RestoreLargestPrefixTests`, `RestoreNoOverwriteAppendedTests`, `MissingDestinationRetryTests`: 87 passed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
