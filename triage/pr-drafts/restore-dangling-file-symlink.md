## What happens

Restoring a symbolic link to a file fails when a link that points nowhere is already at that path.

The restore reports four errors:

```
[Error-...Restore.FileProcessor-VerifyTargetBlocks]: Error during checking the target file
 FileNotFoundException: Could not find file '.../flink.txt'.
[Error-...Restore.BlockManager-BlockCountError]: Block count in SleepableDictionarys block table is not zero: 1
[Error-...Restore.BlockManager-VolumeCountError]: Volume count in SleepableDictionarys volume table is not zero: 1
[Error-...RestoreHandler-RestoreFailures]: Failed to restore 1 local files.
```

The link is also not restored.

This happens in two cases:

- **The link's target is gone.** This is common, for example a link into a drive that is not mounted. There is nothing to restore except the link itself, yet the restore ends with errors.
- **The link was replaced by one that points nowhere.** The restore leaves that dangling link in place instead of putting the backed-up link back.

The measurements below used the new restore flow, restoring to the original location:

| At restore time | Windows | Linux |
|---|---|---|
| the link, target deleted | 4 errors | 4 errors |
| a link to a path that does not exist | 4 errors, link not put back | 4 errors, link not put back |
| a link to another file that exists | link put back, that file untouched | same |
| nothing | link restored | same |

The legacy restore (`--restore-legacy`) restores the link without errors.

## Why

A symbolic link has no content of its own. Its blockset is `SYMLINK_BLOCKSET_ID`, which has no blocks, and the link is made from its metadata.

`FileProcessor.VerifyTargetBlocksAsync` still opens whatever is at the path to compare it block by block. Opening a link reads the file it points to. When that file does not exist, the open throws, and the file is recorded as failed.

## The change

`VerifyTargetBlocksAsync` skips the comparison for symbolic links. The link is made from its metadata, as before.

## Checked

`RestoreDanglingSymlinkTests`, before and after, on Windows and Linux:

| Test | Before | After |
|---|---|---|
| `ALinkWhoseTargetIsGoneIsRestoredWithoutErrors` (with and without `--overwrite`) | fails, 4 errors | passes |
| `ADanglingLinkInPlaceOfALinkIsReplaced` (with and without `--overwrite`) | fails, 4 errors | passes |
| `ALinkToAnotherFileIsReplacedWithoutTouchingThatFile` (with and without `--overwrite`) | passes | passes |
| `ALinkWhoseTargetIsGoneIsRestoredWithoutErrorsByTheLegacyRestore` | passes | passes |

These existing tests pass before and after:

- `SymLinkTests`
- `RestorePathTraversalTests` (including the three symbolic link tests that run only on Linux)
- `Issue5825RestoreNoOverwriteAsync`
- `Issue5957RestoreModifiedBlockUseLocalBlocksAsync`
- `AbortedRestoreOverExistingFilesDoesNotBlameThemAsync`

The tests are skipped where symbolic links cannot be made.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
