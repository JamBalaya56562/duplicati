An index file can be left at the destination for a block volume that no longer exists. Every recreate then reports that block volume as missing again (#4507, #4586).

## Cause

During recreate, the block volume named by the index file is registered as temporary. When no file uses its blocks, `CleanupMissingVolumesAsync` drops it again, with its `IndexBlockLink` rows. The index file stays as an index without blocks.

Repair only deletes such an index file when it is 2 KiB or smaller. A real index file is larger (8061 bytes in the test), so repair keeps it with the `LargeEmptyIndexFile` warning. The next recreate reads it and reports the missing block volume again. The comment there said the index would be kept until the next compact, but nothing deleted it.

## The change

`CleanupMissingVolumesAsync` now sets an uploaded or verified index file to `Deleting` when it only describes the block volumes being dropped. The next operation that changes the destination (backup, repair, compact) deletes it from the destination with the existing cleanup of `Deleting` volumes.

`purge-broken-files` does not delete it, as it lists the destination in verify-only mode.

## Testing

New tests in `OrphanIndexVolumeTests` delete a block volume, recreate the database, run an operation and then recreate again:

| test | master | this branch |
|---|---|---|
| `AnIndexFileForAMissingBlockVolumeIsRemovedAfterRecreate("backup")` | **fail**: the index file stays and the next recreate warns | pass |
| `AnIndexFileForAMissingBlockVolumeIsRemovedAfterRecreate("repair")` | **fail**: the same | pass |
| `ADryRunKeepsTheIndexFile` | pass | pass |
| `OtherIndexFilesAreKept` (and `test` passes) | pass | pass |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `OrphanIndexVolumeTests`, 4 passed. Before the rebase, 13 classes around recreate, repair and purge, 101 passed. No warnings in the changed files.

Fixes #4507
Fixes #4586

🤖 Generated with [Claude Code](https://claude.com/claude-code)
