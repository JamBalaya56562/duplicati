Fixes #6252

## What happens

With `--disable-file-scanner`, the files are not counted before the backup. The progress takes the number and size of the files from the previous backup instead (`LocalBackupDatabase.GetLastBackupFileCountAndSizeAsync`).

That method looked up the newest fileset by its timestamp. `BackupHandler` calls it after it has created the fileset of the backup that is running, so the newest fileset is that one, and it is still empty. The count is 0, and the size, a `SUM` over no rows, is NULL, which is read as -1. While the files were processed, the progress therefore showed `TotalFileCount` 0 and `TotalFileSize` -1, the values in the report, and the UI showed a negative number of files to go.

`BackupHandler` already has the ID of the previous fileset (`lastfilesetid`), from before it creates its own.

## The change

- `GetLastBackupFileCountAndSizeAsync` takes the ID of the fileset to count, and `BackupHandler` passes `lastfilesetid`.
- With no previous backup (`lastfilesetid` is -1), the totals are 0.
- A fileset with no files has a size of 0 rather than -1.

When all files are processed, the backup still sets the totals to what it examined, as before.

The totals are those of the previous backup, so when this backup has more files, the files processed pass them before the end, and with no previous backup they are 0. The second commit makes the old UI (`ngax/scripts/controllers/StateController.js`) handle that: the files and size to go stop at 0, and the progress bar stays at 0 while the total size is not known (0 or less), instead of dividing by it.

## Red to green

`DisableFileScannerProgressTests.TheTotalsComeFromThePreviousBackup` (new) backs up three files of 60 bytes in all twice with `--disable-file-scanner`, and reads the totals from the progress when the first file is listed. They have to be read then, because the backup replaces them with what it examined once all files are processed. The test uses the `TestMethodCallback` hook of Debug builds, as `DisruptionTests` does.

| | Before | After |
|---|---|---|
| First backup (no previous backup) | **red**: 0 files, -1 bytes | 0 files, 0 bytes |
| Second backup | **red**: 0 files, -1 bytes | 3 files, 60 bytes |

`Issue6820`, `SyntheticFilelistMetadataTests` and `DisruptionTests`, which also back up with `--disable-file-scanner`, pass (Windows).

There is no test framework for the `ngax` scripts, so the old UI was checked in a browser (Chromium), on the home page of a local server, by setting the progress event on the real `StateController` scope and reading the status text and the progress:

| Progress (total files / size, processed files / size) | Before | After |
|---|---|---|
| 0 / -1, 5 / 500 (what the server sent before this PR) | "-5 files (-501 bytes) to go", progress -500 | "0 files (0 bytes) to go", progress 0 |
| 3 / 60, 5 / 100 (more files than the previous backup) | "-2 files (-40 bytes) to go", progress 0.9 | "0 files (0 bytes) to go", progress 0.9 |
| 0 / 0, 2 / 20 (no previous backup) | "-2 files (-20 bytes) to go", progress 0.9 (a division by 0, capped) | "0 files (0 bytes) to go", progress 0 |
| 10 / 1000, 4 / 400 | "6 files (600 bytes) to go", progress 0.4 | the same |

## Not covered

The new UI shows the files to go as total minus processed in the same way; that is fixed separately in ngclient.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
