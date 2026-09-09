Builds on #7364: it reuses `ReleaseUnusedBlocksAsync` from there. Open this after #7364 is merged, rebased on master.

## What happens

The block manager counts every block of every file, its metadata included, and holds a block and its volume until the count reaches zero. A file that the restore skips never releases its blocks. They are held until the end of the restore, and then reported as `BlockCountError` and `VolumeCountError`.

A restore that skips one file therefore reports two extra errors that say nothing about the file. When a copy of the file already exists, nothing is wrong at all, yet the restore still ends with these two errors.

## The change

The paths that skip a file now release its unused blocks, the way a file that fails part way does since #7364:

- checking the existing target file fails;
- the block counts do not match;
- an empty file cannot be created;
- the file has blocks in no volume (negative volume ID).

For a file whose copy already exists, the missing blocks are counted as found, since the copy holds them. They are released with the blocks found in the target file.

## Red to green

Four new tests in `RestoreFileFailureTests`. Each checks that the other files are restored and that no block or volume count error is logged.

| Test | Before | After |
|---|---|---|
| A file in the way cannot be read (held open without sharing on Windows, no permissions elsewhere), with overwrite | **red**: `BlockCountError ... 21` (20 data blocks + 1 metadata block) | green |
| A folder where an empty file should go | **red**: `... 1` | green |
| The database places a file's blocks in no volume | **red**: `... 21` | green |
| A different file is in the way, and the copy named after the date already has the right content | **red**: `... 20`, and the restore reports errors | green, with no errors |

Measured on Windows and on Linux (ext4, WSL) with the same results.

`RestoreOtherProcessIsUsingFileAsync` expected four errors for a locked file, two of which were these count errors. It now expects two: the error for the file, and the list of files that failed.

The block count mismatch path is changed the same way, but it cannot be reached without an inconsistent verification, so it has no test.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
