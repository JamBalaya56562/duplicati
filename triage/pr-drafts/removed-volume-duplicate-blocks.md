# Drop the duplicate block records of volumes that are cleaned up

A compact writes the blocks it keeps into a new block volume and records each of them in `DuplicateBlock` for that volume. Once the volume is uploaded, the records are used to move the blocks over to it.

If the compact is stopped before the upload completes, the volume is left in the `Uploading` state. The next cleanup (`repair`, or the start of a backup) removes it with `RemoveRemoteVolumesAsync`. That method deletes the volume's `Block`, `DeletedBlock` and `IndexBlockLink` rows, but not its `DuplicateBlock` rows.

`Remotevolume.ID` is an `INTEGER PRIMARY KEY` without `AUTOINCREMENT`, so when the removed volume had the highest id, the next volume gets the same id. When that is the block volume of the next compact, the volume inherits the records of blocks it does not hold. From there:

- `test` reports the blocks as `Missing` from that volume.
- `test` also treats its index file as faulty, and rewrites it from the database with those blocks in it, so the wrong claim reaches the destination.
- After a database recreate, a restore can pick that volume for the blocks. In one case on current master (31bf7aa0225f095de70020700224d3f229dcfe65) the whole restore then stopped with `NullReferenceException` in `BlockVolumeReader.ReadBlock`. The data itself was still in its original volume.

This change also removes the `DuplicateBlock` rows that point to the removed volumes, or to the blocks removed with them, because block ids are reused the same way.

## Testing

- New `RemovedVolumeDuplicateBlockTests.CleaningUpAVolumeRemovesItsDuplicateBlocksAsync`:
  - It leaves the state a stopped compact leaves: a block volume in the `Uploading` state that is not at the destination, recorded as holding copies of some blocks.
  - Then it runs repair and compact, checks that the compact's volume took the freed id, and runs `test all`, a recreate and a full restore.
  - On master it fails: two duplicate records remain on the reused id, and without that assertion `test all` reports the volume with errors. With the change it passes.
- Related tests (`RepairHandlerTests`, `RepairWithMissingRemoteFiles`, `RepairFilesetTimestampTests`, `PurgeTesting`, `Issue6070`, `ZeroLengthMetadataTests`, `CompactDisruptionTests`, `CompactBlockVolumeIdConstraintTests`, `FailedOperationDatabaseTests`, `SoftDeleteTests`, `DryRunTests`): 94 passed, including the new one.
- The CLI on Windows, 3 runs of 40 rounds. Each round kills `compact` at a random point 0.3 to 3.5 seconds in, then runs `repair`, `compact` and `test all`. `test all` reported missing blocks in 11 of the 120 rounds on master, and in none with this change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
