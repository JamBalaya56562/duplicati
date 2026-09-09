`LocalDeleteDatabase.PrepareForDeleteAsync` removes the `DuplicateBlock` rows of the blocks that compact moved. It did this by joining `BlockID` and `VolumeID` into a string on both sides of an `IN`, so every row of `DuplicateBlock` was turned into a string and compared. This runs once for each block volume that compact deletes (`CompactHandler.cs`).

## The change

The delete now uses a row-value `IN` on the two columns. SQLite can then use the unique index `UniqueBlockVolumeDuplicateBlock (BlockID, VolumeID)`, in the same way as the recreate code already updates `DuplicateBlock` (`LocalRecreateDatabase.cs`). Both columns are integers and never null, so the same rows are deleted.

## Measurements

The delete alone, with the pragmas of `SQLiteLoader`, an open transaction and `ANALYZE`. Each figure is the median of 5 runs, alternating between the old and the new statement.

| `DuplicateBlock` rows | replaced blocks | before | after |
|---|---|---|---|
| 100k | 1k | 41.4 ms | 3.0 ms |
| 1M | 1k | 245.7 ms | 2.7 ms |
| 1M | 10k | 468.5 ms | 31.4 ms |
| 4M | 10k | 1176.1 ms | 23.4 ms |

## Testing

Earlier, on Windows, the compact and duplicate-block tests passed (13 classes, 32 tests). With the delete broken to `WHERE 0 AND`, 8 of them failed.

Run again after rebasing onto master [c16a28aa8](https://github.com/duplicati/duplicati/commit/c16a28aa8cfb8564fa23b9caa5499b33711aae80), in one build with the other branches I am opening today: 48 tests passed, among them the tests with `Compact` in their name. No new warnings in the changed file.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
