# Let the test operation check a block volume without blocks

A backup can upload a block volume that holds no blocks. `DataBlockProcessor` opens a volume for a blocklist hash even when the block itself is already stored, because the hash must go to the index file, and it uploads the volume at the end when `blocklistHashesAdded > 0`, even if `SourceSize` is 0.

That happens, for example, after `purge-broken-files` removed a file from every version. The next backup of the file finds its blocklist block already stored, but no version refers to it, so the hash goes to the index file of a new volume, which gets no data when the other blocks went to another volume.

`test` then failed on that volume:

```
duplicati-b....dblock.zip (errors):
[Error, Index was out of range. Must be non-negative and less than the size of the collection. (Parameter 'index')]
```

`TestVolumeInternalsAsync` computed the sample count as `Math.Min(Math.Max(0, count * percent), count - 1)`, which is -1 for an empty volume, and then removed an element from the empty sample list. The sample count is now never below zero.

This is what failed #7644 on macOS: its new test runs `test` after a purge-broken-files and a backup. It is not caused by the change in #7644.

## Testing

- New `TestEmptyBlockVolumeTests.ABlockVolumeWithoutBlocksPassesTheTestAsync`: backs up a large and a small file with `concurrency-compressors=1`, moves away a volume that holds only data blocks of the large file, runs purge-broken-files, backs up again, checks that one uploaded block volume has no blocks, and runs `test` on every volume.
  - Without the change: fails with the error above.
  - With the change: passes (2 runs).
- With `concurrency-compressors` 1, 2, 4 and 8 on the test of #7644, two runs each: the empty volume appeared in both runs with 1, in one of the two with 8, and not with 2 or 4.
- `EmptyFileTests`, `AutomaticIndexTests`, `IndexRecreationTests`, `Issue5066`, `Issue5845`, `Issue5862`, `ArchiveAttributeTests`, `DryRunTests` and the new test: 26 passed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
