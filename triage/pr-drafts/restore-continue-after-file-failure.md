## What happens

When the restore cannot create or write one file, for instance because a folder is in its way, another program has it open, or the disk cannot hold it, the file processor that was restoring it rethrows and stops. With one file processor, which is the default on a machine with two or three cores (`restore-file-processors` is half the processor count), the restore then fails with that one file's error and none of the files after it are restored.

The other ways a single file can fail already carry on with the next file: checking the existing target file, and creating an empty file. #6966 did the same for metadata (#6845, where the reporter asked what other file restores might have been cut off).

## The change

A failure of one file is reported as before (`BrokenLocalFiles` and an error in the log), and the processor carries on with the next file. A retirement, which is a failure of the restore itself such as a volume that cannot be downloaded, still ends the processor as before.

Two things have to be put right before the next file can start, which is presumably why the processor stopped instead:

- **The responses to the requests sent ahead.** The processor sends up to `restore-channel-buffer-size` download requests ahead of the block it is writing, so when a file fails, responses for it can still be on their way. They are read and dropped. Without this, the next file takes them for its own blocks, and the processor and the block manager end up waiting on each other (measured: the restore hangs).
- **The block counts.** The block manager counts every block a file needs, its metadata included, and keeps a block and its volume until the count reaches zero. The blocks the failed file will not use are released, so they are not held until the end of the restore and then reported as `BlockCountError`.

The file is closed in the handler, so a file that also fails to close, as it can when flushing to a full disk, does not end the processor either.

## Red to green

`Duplicati/UnitTest/RestoreFileFailureTests.cs` (new). Real backup and restore with one file processor, four requests sent ahead, and the blocks taken from the backup rather than the source files. The failing file is the largest, and the restore takes files largest first, so the ten other files all come after it. Each test checks that the ten are restored with their content, that only the failing file is reported, and that no `BlockCountError` or `VolumeCountError` is logged.

| Test | Before | After |
|---|---|---|
| A folder is in the way of the file, so it cannot be created (fails before any block is requested) | **red**: the restore fails with `UnauthorizedAccessException`, the other files are not restored | green |
| The database gives the file a size of 1 PiB with `restore-preallocate-size`, so reserving the size fails right after the first requests for the file were sent | **red**: the restore fails with `ArgumentOutOfRangeException` from `SetLength`, the other files are not restored | green |

Measured on Windows, and on Linux (ext4, WSL) with the same results.

To check that the tests cover each part of the change, each part was taken out in turn:

- Without dropping the responses sent ahead: the second test fails at its two-minute limit (the restore hangs).
- Without releasing the blocks: both tests fail with `BlockCountError: ... not zero: 21` (20 data blocks and 1 metadata block).
- Without releasing the metadata blocks only: both fail with `not zero: 1`.

The existing restore tests that go near this code pass (21: `RestoreHandlerTests` for aborted, stopped, empty-file, locked-file, retarget and skip-larger-than restores, `RestoreCallbackModuleTests`, `Issue5987`).

## Not covered

- A **priority file** that fails still faults the priority barrier, and processors waiting on it stop, as with the other ways a file can fail.
- The existing per-file failures that already carry on (checking the target file, creating an empty file) do not release their blocks, so they can still log `BlockCountError`. Unchanged here.

This touches the same `catch` as #7359, so whichever lands second needs a small rebase.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
