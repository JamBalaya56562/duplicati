## What happens

`IsBlockDevice` is not only true for block devices. The Linux and macOS snapshots answer true for anything that is not a regular file, a folder or a symlink: block and character devices, FIFOs and sockets. The backup leaves all of these out. The name hid that; the log said "block device" for a FIFO until #7405 changed the message.

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

## Checked

- On the current master, together with the other open branches, the whole solution (`proprietary/` included) builds with no errors. After the rebase, `IsBlockDevice` is left only in `PosixFile`, as intended.
- The tests whose entries are renamed pass on Windows: `AbortedSourceReadTests`, `BackupExclusionAttributeTests`, `ChangeTrackingSourceProviderTests`, `ExcludeEmptyFoldersTests`, `Issue6909`, `MetadataContentInDatabaseTests`, `SourceProviderFactorySnapshotOwnershipTests`, `SourceProviderOptionValidationTests` and `TestVirtualSourcePath`, 70 tests.
- Earlier, `SpecialFileExclusionLogTests`, `BackupExclusionAttributeTests` and `Issue6909` passed on Linux.

This is a rename, so no test goes from failing to passing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
