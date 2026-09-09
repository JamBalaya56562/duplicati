**Stacked on `fix/special-file-exclusion-log`**, which changes the log message for the same entries. The diff here is the last commit only.

## What happens

`IsBlockDevice` is not only true for block devices. The Linux and macOS snapshots answer true for anything that is not a regular file, a folder or a symlink: block and character devices, FIFOs and sockets. The backup leaves all of these out. The name hid that; the log said "block device" for a FIFO until the branch below this one changed it.

## The change

`IsBlockDevice` is now `IsSpecialFile`, on `ISnapshotService` and `ISourceProviderEntry`, with every implementation:

- the snapshots (`SnapshotBase`, `NoSnapshotLinux`, `LinuxSnapshot`, `MacOSSnapshot`, `WindowsSnapshot`) and `SnapshotSourceFileEntry`;
- the macOS Photos entries and `BackendSourceFileEntry`;
- the Office 365, Google Workspace and disk image sources in `proprietary/`;
- the test entries that implement the interface;
- the column of the source tool's `list` command, which is now `IsSpecialFile`.

The documentation says what the member answers. `PosixFile`'s own `IsBlockDevice` and `FileType.BlockDevice` are left alone: those do mean a block device.

The disk image source's physical drive and machine root entries are still true, as a block device is a special file. They are meta entries, which the backup does not filter, so they are not left out.

Nothing changes in which entries are left out.

## Compatibility

- A source provider built outside this repository that implements `ISourceProviderEntry` needs the new name.
- Output of the source tool's `list` command names the column `IsSpecialFile`.
- `AbortedSourceReadTests`, added by #7399, has a test entry that implemented `IsBlockDevice`. It is renamed here too: without that, this branch merged with master failed to build with CS0535.

## Checked

- The whole solution, `proprietary/` included, builds with no errors.
- `BackupExclusionAttributeTests`, `Issue6909`, `MetadataContentInDatabaseTests`, `SourceProviderOptionValidationTests` and `SpecialFileExclusionLogTests` pass on Windows (20 tests, 1 skipped as Linux and macOS only).
- `SpecialFileExclusionLogTests`, `BackupExclusionAttributeTests` and `Issue6909` pass on Linux (4 tests).
- On master with #7399, the build failed with CS0535 in `AbortedSourceReadTests` before that test entry was renamed, and builds after. `AbortedSourceReadTests`, `SpecialFileExclusionLogTests` and `MetadataContentInDatabaseTests` then pass on Windows (8 tests, 1 skipped).

This is a rename, so no test goes from failing to passing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
