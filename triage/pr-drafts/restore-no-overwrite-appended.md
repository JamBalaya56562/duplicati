## What happens

Without `--overwrite`, a restore to the original location keeps a file that differs from the backed-up one. It restores the backed-up version beside it, under a new name (`file.<date>.ext`).

A file that was appended to after the backup is the exception. It is cut back to the backed-up length, and what was appended is lost, with no warning. An empty backed-up file does the same thing: a file written after the backup is cut to nothing.

Measured on Windows and Linux, restoring over the original location with `--overwrite=false`:

| File at restore time | Before |
|---|---|
| `kept` backed up, now `kept-changed` | cut back to `kept` |
| 25 KB backed up, now the same 25 KB plus 5 KB | cut back to 25 KB |
| empty backed up, now 24 bytes | cut to 0 bytes |
| changed in the middle, same length | kept, backed-up version restored beside it (correct) |

The legacy restore (`--restore-legacy`) keeps the appended file and restores beside it, as intended.

## Why

`FileProcessor.VerifyTargetBlocksAsync` reads the existing file block by block, for as many blocks as the backed-up file has. An appended file starts with the backed-up content, so every block and the file hash match, and the file is taken to be the backed-up one. It is longer, so it is then truncated with `SetLength`, and `--overwrite` is never checked.

The restore under a new name was added in [eba477c271fd1b2419d8f4348ed051e0f6f98fd3](https://github.com/duplicati/duplicati/commit/eba477c271fd1b2419d8f4348ed051e0f6f98fd3) for #5825. It only happens when a block is missing (`missing_blocks.Count > 0`), so it never applies to an appended file.

## The change

When the existing file is longer and `--overwrite` is not set, `VerifyTargetBlocksAsync` now treats it as a different file. It is left alone, and the restore continues under a new name, the same as for a file that differs in any other way.

- The matching blocks are not reused for the new file. The copy of local blocks (`CopyOldTargetBlocksToNewTargetAsync`) reads whole blocks, so it would carry the appended bytes after the last block into the restored file.
- The restore to a new name now also happens when no block is missing. This covers the empty file, which has no blocks.

With `--overwrite`, the file is still cut back to the backed-up version, as requested.

## Checked

`RestoreNoOverwriteAppendedTests`, before and after, on Windows and Linux:

| Test | Before | After |
|---|---|---|
| `AnAppendedFileIsNotCutBackWithoutOverwrite` | fails | passes |
| `AnAppendedFileOfSeveralBlocksIsNotCutBackWithoutOverwrite` | fails | passes |
| `AnAppendedFileIsNotCutBackWithoutOverwriteWhenUsingLocalBlocks` | fails | passes |
| `AFileThatWasEmptyIsNotCutBackWithoutOverwrite` | fails | passes |
| `AnAppendedFileIsCutBackWithOverwrite` | passes | passes |
| `AFileChangedInTheMiddleIsKeptWithoutOverwrite` | passes | passes |

These existing tests pass before and after:

- `Issue5825RestoreNoOverwriteAsync` (all 4 cases)
- `Issue5957RestoreModifiedBlockUseLocalBlocksAsync` (all 4 cases)
- `AbortedRestoreOverExistingFilesDoesNotBlameThemAsync`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
