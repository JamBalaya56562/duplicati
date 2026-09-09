# Restore the other files when a block cannot be read from its volume

Two commits:

1. **Name the block when it is not in the volume it is read from.** `ICompression.OpenRead` returns `null` for a file that is not in the archive. `BlockVolumeReader.ReadBlock` passed that on to `Utility.ForceStreamRead`, so reading a block from a volume that does not hold it stopped with a `NullReferenceException`. It now throws an `InvalidDataException` that names the block. The other callers (test, repair, recreate, compact, the legacy restore, the spill collector) get the same exception instead. None of them catches `NullReferenceException`.
2. **Restore the other files.** In the new restore, an unreadable block stopped the whole restore, although only the files that use the block are affected. The restore already handles a block that fails its hash check: it passes the block on, the file then fails its file hash check, it is reported as not restored, and the other files are restored. The legacy restore also carries on with the next file. An unreadable block is now handled the same way. The restore logs which block could not be read (`UnreadableBlock`), passes on a block of zeros, and skips the hash check of the block itself. Every file that uses the block, including files that share it, then fails its file hash check, and the rest of the restore goes on. No channel or process changes, so nothing waits on a block that never comes.

This came up with a destination where an index file listed blocks for a volume that did not hold them (the cause is fixed separately). After a database recreate, the whole restore of current master (31bf7aa0225f095de70020700224d3f229dcfe65) failed with:

```
System.NullReferenceException: Object reference not set to an instance of an object.
   at Duplicati.Library.Utility.Utility.ForceStreamRead(Stream stream, Byte[] buf, Int32 count)
   at Duplicati.Library.Main.Volumes.BlockVolumeReader.ReadBlock(String hash, Byte[] blockbuffer)
```

With this change, the same restore finishes. It reports the three files that use the four unreadable blocks, and restores the other 147:

```
Failed to read block 638 from volume 14, so the files that use it cannot be restored: The block 2d1pG2rb9O6Gj2JSzNBvQsIiuzJsV6ECvqQkN6srJ/w= is not in the block volume
...
Failed to restore 3 local files.
Restored 147 (4.30 MiB) files to ...
```

The CLI still exits with 0 when files failed to restore. That was already the case for other per-file restore failures, because the restore command only maps warnings to an exit code. I left it out of this change.

## Testing

- New `RestoreBlockNotInVolumeTests`:
  - `RestoreSkipsOnlyTheFilesThatUseTheBlockAsync`: a block of one file is moved, in the database, to another block volume. A copy of that file shares the block, and a third file does not. The restore must finish within two minutes, report the two files that use the block, restore the third one intact, and log `UnreadableBlock` with the hash. Without the second commit, the restore stops with the `InvalidDataException` (red).
  - `ReadingABlockThatIsNotInTheVolumeNamesTheBlockAsync`: reads a block that is not in a real block volume. Fails with `NullReferenceException` on master.
- Restore, recreate and repair tests (`RestoreAllFilesTests`, `RestoreFileFailureTests`, `RestoreHandlerTests`, `RestoreDryRunVerificationTests`, `RestoreTestHandlerTests`, `RestoreMissingFolderTests`, `RestoreLargestPrefixTests`, `RestoreNoOverwriteAppendedTests`, `RecreateWithEmptyFilelistTests`, `RepairWithMissingRemoteFiles`): 135 passed, including the new ones. Earlier, with the first commit alone, 151 passed in a wider set of classes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
