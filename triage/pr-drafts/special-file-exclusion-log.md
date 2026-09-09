## What happens

On Linux and macOS the backup leaves out every entry that is not a regular file, a folder or a symlink: block and character devices, FIFOs and sockets. That is right, as reading a FIFO could wait for ever.

The check is `IsBlockDevice`. The POSIX snapshots (`NoSnapshotLinux`, which `NoSnapshotMacOS` derives from, `LinuxSnapshot` and `MacOSSnapshot`) answer true for anything that is not a file, folder or symlink. So the log called all of these a block device.

A backup on Linux of a folder holding a FIFO and a socket, with `/dev/null` as a source of its own, logged:

```
[Verbose-...FileEnumerationProcess-ExcludingBlockDevice]: Excluding block device: .../a-fifo
[Verbose-...FileEnumerationProcess-ExcludingBlockDevice]: Excluding block device: .../a-socket
[Verbose-...FileEnumerationProcess-ExcludingBlockDevice]: Excluding block device: /dev/null
```

None of them is a block device.

## The change

- The message is now `Excluding special file (device, FIFO or socket): {0}`, with the id `ExcludingSpecialFile` instead of `ExcludingBlockDevice`.
- The warning for a failed check is `PathProcessingErrorSpecialFile` instead of `PathProcessingErrorBlockDevice`.
- The comments and documentation of `IsBlockDevice` now say what it answers on Linux and macOS: `ISnapshotService`, `ISourceProviderEntry`, `SnapshotBase`, the three POSIX snapshots, `SnapshotSourceFileEntry`, and the `list` command of the source tool.

Which entries are left out does not change.

A log filter, or a `--suppress-warnings` entry, that names one of the old ids needs the new one. The old ids are not used anywhere else in this repository or in the documentation repository.

The member name `IsBlockDevice` is kept here. `fix/rename-isblockdevice-to-isspecialfile`, stacked on this branch, renames it to `IsSpecialFile`.

## Checked

`SpecialFileExclusionLogTests.SpecialFilesAreLoggedAsSpecialFilesAsync` backs up a folder with a regular file, a FIFO and a socket, plus `/dev/null`. It checks that:

- only the regular file is backed up;
- each of the three is logged as a special file;
- nothing is logged as a block device.

It runs on Linux and macOS, and is skipped on Windows.

| | Before | After |
|---|---|---|
| Linux (2 runs) | fails, the FIFO is logged as a block device | passes |

`BackupExclusionAttributeTests`, `Issue6909`, `MetadataContentInDatabaseTests` and `SourceProviderOptionValidationTests`, whose test entries implement `IsBlockDevice`, pass on Windows (20 tests).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
