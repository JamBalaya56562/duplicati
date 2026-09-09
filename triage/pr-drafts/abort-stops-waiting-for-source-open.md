Part of #6461. This fixes one of the places where "Stop now" left a backup running for ever: opening a source file that is stuck.

## What happens

Opening a source file is a synchronous call that does not look at the cancellation token: the snapshots open the file before they return the task. On a source that stopped answering, as a network share can, the open gets stuck, and "Stop now" never made the backup return.

Measured on Linux against a small FUSE file system that stops answering the open of one file: the backup had not returned 30 s after the abort.

## The change

The file block processor opens the file on its own task, and stops waiting for it when the operation is aborted, as the backend manager does for a backend call (#7325). If the file opens after that, the stream is closed again, so no handle is left open.

## Checked

`AbortedSourceOpenTests.AbortedBackupWithAStuckFileOpenReturnsAsync` backs up a test source whose file open blocks, as a file open does, and ignores the token. The test then:

1. aborts once the open is stuck, and expects the backup to return with the cancellation;
2. releases the stuck open, and checks that the stream it returns is closed;
3. checks that the local database file can be opened exclusively.

| | Before | After |
|---|---|---|
| Windows | fails, still running 30 s after the abort | passes 3 of 3 |
| Linux, file on a FUSE file system that stops answering the open | still running 30 s after the abort | returned 0.15 s after the abort |

The test entry is a `DispatchProxy`, so it does not name the members of `ISourceProviderEntry`.

The cost of opening each file on its own task, measured on Windows in a Release build:

- Opening 20,000 cached 1-byte files, the direct open and the open on its own task in turn, five rounds: the task was slower in every round, by about 39 µs per open. The direct open alone varied from 1.0 s to 2.2 s per round.
- Backing up 20,000 files of 1 KB into an empty destination, switching between the two builds in turn, four rounds each: 78.6 s before and 79.0 s after on average. The same build varied from 63 s to 93 s, so the difference cannot be told apart. Estimated from the cost per open, it would be about 1% of such a backup.

`AbortedBackupTests`, `DisruptionTests`, `SymLinkTests`, `SyntheticFilelistMetadataTests`, `DryRunTests`, `Issue6366` and `Issue6820` also pass (50 tests, Windows). The branch also merges without conflicts with the fix for a stuck size or metadata read, and both new test classes pass on the merge (6 tests).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
