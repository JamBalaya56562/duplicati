# Do not recreate a destination folder that disappears during an operation

The backend manager creates a missing destination folder when an operation gets a `FolderMissingException`, unless something has already been uploaded or downloaded. That rule creates the folder for a first backup, and should not create it again when it goes away later.

A listing did not count. A backup lists the destination before it uploads anything. If the folder disappears after the listing but before the first upload completes, for example because a USB drive is unplugged or a network share drops, the first upload fails with `FolderMissingException`. The folder is then created again, and the backup carries on into a new, empty folder in the same place, which can be on the disk the drive was mounted on. Once the drive is back, the destination is missing everything that backup wrote:

```
The operation Backup has failed => Found 11 files that are missing from the remote storage, please run repair
```

`repair` then reports missing dblock files, and the way out is `--rebuild-missing-dblock-files` or `purge-broken-files`.

With this change, a listing that found files also counts. A folder that has never existed still gets created, because its listing fails. A folder that exists but is empty also still gets created again.

## Testing

- New `VanishingDestinationTests.ABackupDoesNotRecreateADestinationThatDisappearsAsync`. It uses a test backend that wraps the file backend and moves the destination folder away just before the first upload. On master the folder is created again (red). With the change, the backup fails and the folder is not created.
- Found with a stress test on current master (31bf7aa0225f095de70020700224d3f229dcfe65), Linux: the destination was renamed away at a random point during 25 backups, and one of them wrote 11 files into a recreated folder.
- Related tests (`MissingDestinationRetryTests`, `FailedOperationDatabaseTests`, `AbortedBackupTests`, `Issue1282`, `Issue5845`, `Issue5862`, `Issue7271Tests`, `SoftDeleteTests`, `CommandLineOperationsTests`): 24 passed in one run. `CommandLineOperationsTests.RunCommands` failed once in that run, and passed when rerun alone on the same build.

`LightWeightBackendManager`, which the remote synchronization tool uses, has the same rule and the same gap. It is not changed here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
