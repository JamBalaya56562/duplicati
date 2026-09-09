Part of #6461. This fixes one of the places where "Stop now" left a backup running for ever: a source file read that is stuck. Opening a file, reading its metadata and listing folders can also get stuck on a source that stopped answering; this does not cover them.

## What happens

The backup reads each source file a block at a time, and passes the cancellation token on to the read. Not every stream ends a stuck read when the token is cancelled.

Measured with real OS handles opened for synchronous reads, as `SnapshotBase.OpenRead` opens a source file, with the other end sending nothing:

| | Windows, named pipe | Windows, file through a network redirector (`\\wsl.localhost`) | Linux, FIFO |
|---|---|---|---|
| The read ends when the token is cancelled | yes | yes | **no**, still pending 3 s later |
| The wait ends when wrapped in `WaitAsync(token)` | yes | yes | yes |
| Disposing the stream with the read stuck returns | at once | at once | at once, and the read stays pending |

So on Linux a read that is stuck, as from a network share that stopped answering, held up the backup, and "Stop now" never made it return. On Windows a `FileStream` read ends on cancel, so this matters there only for a stream that ignores the token. `BackupDataStream`, used with `--backup-privileges`, does not override `ReadAsync`, so it uses `Stream.ReadAsync`, which does not end a stuck read on cancel (the test stream below does the same). I could not get a `BackupRead` itself to hang to check it directly.

To check the whole backup against a real stuck read on Linux, I backed up a folder on a small FUSE file system whose regular file stops answering reads after its first 64 KB, and aborted once the read was stuck:

| | Before | After |
|---|---|---|
| Linux, regular file on a stuck FUSE file system | still running 30 s after the abort | returned 0.5 s after the abort, with the cancellation |

## The change

The block splitter now stops waiting for the read when the operation is aborted, as the backend manager does for a backend call (#7325). The read is left to end by itself.

- The buffer the read writes into is not returned to the pool on that path. The splitter only hands buffers on inside blocks, so a read that ends later cannot write into a buffer that was handed out again.
- `FileBlockProcessor` then disposes the stream with the read still pending. As measured above, that returns at once.

## Checked

`AbortedSourceReadTests.AbortedBackupWithAStuckSourceReadReturnsAsync` backs up a test source whose file read stops answering after the first blocks and ignores the token. The test then:

1. aborts once the read is stuck, and expects the backup to return with the cancellation;
2. releases the stuck read, and checks that it ends;
3. checks that the local database file can be opened exclusively.

| | Before | After |
|---|---|---|
| Windows | fails 2 of 2, still running 30 s after the abort | passes 3 of 3, in about 1 s |
| Linux | fails, still running 30 s after the abort | passes |

The cost of the change itself, measured on Windows in a Release build: reading a cached 256 MB file the way the splitter does (opened as `SnapshotBase.OpenRead` opens it, `ForceStreamReadAsync` per block), five rounds each, alternating:

| Block size | Without `WaitAsync` (rounds 3 to 5) | With `WaitAsync` (rounds 3 to 5) |
|---|---|---|
| 100 KB (2,622 reads) | 216, 178, 185 ms | 222, 186, 181 ms |
| 1 MB (256 reads) | 94, 96, 97 ms | 95, 93, 95 ms |

Neither is faster in every round, so the cost is below a few microseconds per read. For a 512 MB backup read in 100 KB blocks, that is well under 20 ms.

Timing whole backups of 512 MB could not show a difference either way. Switching between the two builds in turn, four times each, the same build varied from 17.5 s to 28.9 s over the session, more than any difference between them.

`AbortedBackupTests`, `DisruptionTests` and `MetadataContentInDatabaseTests` also pass (46 tests, Windows). The branch also passes merged with the other two fixes for #6461 (the block hand-off in #7395, and a stop that comes before the operation is ready).

Note: the test entry here implements `ISourceProviderEntry.IsBlockDevice`. `fix/rename-isblockdevice-to-isspecialfile` renames that member to `IsSpecialFile`; the two merge without a text conflict, but the merged build fails with CS0535. Whichever lands second needs the name changed in `AbortedSourceReadTests`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
