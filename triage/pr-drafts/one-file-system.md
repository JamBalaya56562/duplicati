Title: Add --one-file-system to leave out folders on other file systems

Backing up `/` on Linux or macOS also walks into mounted disks, network shares and virtual file systems such as `/proc` (#1530). There was no way to stay on one file system, as rsync's `--one-file-system` does.

## The change

- New option `--one-file-system` (off by default). When the operation starts, it lists the mount points and leaves out those below a source folder (new `Operation/Backup/OtherFileSystems.cs`).
  - Linux and macOS read the mount points from `DriveInfo.GetDrives()`.
  - Windows uses `FindFirstVolumeW` and `GetVolumePathNamesForVolumeNameW`, so volumes mounted in a folder are found too.
- A source folder is kept even when it is a mount point itself, and so are its parents. Remote sources (`@...`) are not affected.
- The mount points are added to the excluded paths of `BackupHandler.GetBlacklistedPaths(options, sources)`, which backup, the file counter, sync and test-filters all use. The help says that the mount point folder itself is left out too (rsync keeps it as an empty folder), and that on Windows a mounted folder is only entered with `--symlink-policy=follow`.

## Testing

`OneFileSystemTests`:
- 3 tests of the selection logic and 1 that the system root is listed. These pass on Windows and Linux.
- 2 end-to-end tests that run only when `DUPLICATI_TEST_ONE_FILE_SYSTEM_SOURCE` points to a folder with a mount below it.
  - On Linux (WSL, a tmpfs mounted below the source) and on Windows (a 64 MB VHDX mounted in a folder), both pass.
  - When the option is ignored, the one with the option turned on fails: the files of the mounted volume end up in the backup.

All pass after the rebase on the current master: 4 pass and 2 are skipped without a mount.

Fixes #1530

🤖 Generated with [Claude Code](https://claude.com/claude-code)
