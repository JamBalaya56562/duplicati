Part of #6461. This fixes the places after the listing where "Stop now" left a backup running for ever: reading the size or the metadata of a source entry that is stuck.

## What happens

Reading the size of an entry and reading its metadata (the extended attributes) are synchronous calls that do not look at the cancellation token. On a source that stopped answering, as a network share can, they get stuck:

- The pre-filter reads the size of every file, and the metadata processes read the metadata of every file and folder. When one of those reads is stuck, "Stop now" never made the backup return.
- The progress count reads the size of every file on the side. When its read is stuck and the backup is aborted, the backup waited 500 ms for the count, then threw a `TimeoutException`, so an aborted backup ended with a timeout instead of the cancellation. When its read is stuck and the backup finishes, the backup waited for the count for ever.

Measured on Linux against a small FUSE file system that stops answering attribute reads (after the given number of them) or extended attribute reads. The listing and the file open were already fixed in these builds (the other two fixes for #6461), so the reads got stuck in the later stages:

| The file system stops answering | Before | After |
|---|---|---|
| attribute reads, after 13 | returned in 1.5 s, with a `TimeoutException` | returned in 1.4 s, with the cancellation |
| attribute reads, after 30 | still running 30 s after the abort | returned in 0.3 s, with the cancellation |
| attribute reads, after 40 | returned in 0.2 s, with the cancellation | returned in 0.7 s, with the cancellation |
| extended attribute reads, after 2 | still running 30 s after the abort | returned in 0.3 s, with the cancellation |

Which stage an attribute read gets stuck in varies from run to run. After 40, the build without this change returned as well, so that read was not stuck in one of the places this changes.

## The change

- The pre-filter and the progress count read the size on its own task, and stop waiting for it when the operation is aborted (the count also when it is stopped at the end of the backup).
- The backup reads the metadata through `MetadataGenerator.GenerateMetadataUnlessAbortedAsync`, which reads it on its own task in the same way. The repair keeps calling `GenerateMetadataAsync` as before.
- When the pre-filter stops waiting for the size, the cancellation is passed on instead of being logged as a failure to read the size.
- Waiting for the progress count after a failure no longer throws: both waits give the count 500 ms to stop, as before, and then leave the outcome of the operation as it is.

## Checked

`AbortedSourceMetadataTests` backs up a test source that gets stuck in one place, and ignores the token there:

| Case | Where the source gets stuck | Before | After |
|---|---|---|---|
| `AbortedBackupWithAStuckSourceReturnsAsync(Size, false)` | the size, progress count off | still running 30 s after the abort | returns with the cancellation |
| `AbortedBackupWithAStuckSourceReturnsAsync(Size, true)` | the size, progress count on | still running 30 s after the abort | returns with the cancellation |
| `AbortedBackupWithAStuckSourceReturnsAsync(FileMetadata, false)` | the metadata of the file | still running 30 s after the abort | returns with the cancellation |
| `AbortedBackupWithAStuckSourceReturnsAsync(FolderMetadata, false)` | the metadata of the folder | still running 30 s after the abort | returns with the cancellation |
| `BackupFinishesWhileTheProgressCountIsStuckAsync` | the size, in the progress count only, no abort | not finished 30 s later | finishes |

Measured on Windows. Before, each case was run on its own, as a backup that is left stuck by one case holds up the next. After, all five pass together, three runs out of three. The source gets stuck only when the call comes from the stage under test (checked on the stack), so the listing, which also reads the extended attributes, does not get stuck first.

Each part is needed on its own. With the progress count change taken out, `BackupFinishesWhileTheProgressCountIsStuckAsync` fails again. With the change to the waits taken out as well, `(Size, true)` returns, but with a `TimeoutException`.

The cost of reading the size on its own task, measured on Windows in a Release build:

- Reading the size of 20,000 cached files directly and on its own task in turn, five rounds: about 46 µs more per read in every round.
- Backing up 20,000 files of 1 KB into an empty destination, switching in turn between master and a build with the size and metadata reads on their own tasks (a prototype of this change, on top of the file open fix), four rounds each: 82.1 s and 80.3 s on average, so no slowdown could be seen. The same build varied from 67 s to 103 s, so a difference below about 10% cannot be told apart. Estimated from the cost per read (about three reads per file), it would be about 3% of such a backup.

`AbortedBackupTests`, `DisruptionTests`, `SymLinkTests`, `SyntheticFilelistMetadataTests`, `DryRunTests`, `Issue6366` and `Issue6820` also pass (50 tests, Windows). The branch also merges without conflicts with the fix for a stuck file open, and both new test classes pass on the merge (6 tests).

## Not covered

- `MetadataPreProcess` reads the last write time and the attributes, and `StreamBlockSplitter` reads the length of the stream. In the runs above none of them got stuck, so they are left as they are.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
