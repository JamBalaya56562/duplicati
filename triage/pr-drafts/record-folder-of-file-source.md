When a file is chosen as a source, its folder is not part of the backup. If a restore has to create that folder, it has no metadata for it, so with `--restore-permissions` the folder gets the owner of the user that runs the restore, and the times of the restore, instead of the original ones (#6863).

## The change

The folder of a file source is now recorded too, right after the file:

- Only the folder itself is recorded, not the other entries in it. This is the same as choosing the folder with a filter that keeps only the file.
- It is not added when a source folder already covers it, or when another file source in the same folder already added it.
- The filters apply to it, so a folder that is excluded is not recorded.
- It is added after the file, so `--exclude-empty-folders` does not see it as an empty folder.

The shared code is `ParentFolderSourceEntry.WithFoldersOfFileSources` in `Duplicati.Library.Snapshots`. It is used by the regular scan (`LocalFileSource.EnumerateAsync`) and by the full scan of the USN journal (`UsnJournalService.GetFullScanSources`). `ParentFolderSourceEntry` derives from `SnapshotSourceFileEntry` and only overrides `Enumerate`, which is now `virtual`.

### Visible effect

When the backup is listed for a restore, the folder of a file source is now a root, with the chosen files and folders in it, and a search finds it. Three tests in `DirectListHandlerTests` are changed for this (`ListFolderContentsAsync`, `ListFolder_RootsIncludeASourceThatExtendsAnotherSourcesNameAsync` and the counts in `SearchFilesTestAsync`). The case that test was written for, a root whose name extends another root, is still covered by `GetMinimalUniquePrefixEntries_FileRootsDoNotAbsorbLongerNamesAsync`, which writes the entries to the database directly.

A restore to another folder puts the files in the same place as before. The target folder gets the times of the recorded folder, as when the folder itself is a source.

## Testing

New `BackupParentOfFileSourceTests`, 4 tests:

| | master | this branch |
|---|---|---|
| the folder is recorded and its times are restored (with and without `--exclude-empty-folders`) | **fail** (2) | pass |
| a folder excluded by a filter is not recorded | pass | pass |
| a folder that is also a source is recorded once | pass | pass |

New `UsnSourceFileBackupTests.TheFolderOfASourceFileIsRecordedWithTheJournal` checks that the folder is kept in the first and the second backup with the USN journal. It needs to run as administrator, so I could not run it locally; I expect it to run on the Windows CI.

With `DirectListHandlerTests` and the other source and restore tests, 125 tests pass on Windows (1 skipped). No new warnings in the changed files.

I also tried the report on Linux (WSL, as root): a file in a folder owned by `nobody:nogroup` with mode 750 and an old time, backed up as the only source, the folder deleted, then restored with `--restore-permissions`.

| | restored folder |
|---|---|
| master | `root:root`, 755, the time of the restore |
| this branch | `nobody:nogroup`, 750, `2001-02-03 04:05:06` |

Not tried: macOS.

Fixes #6863

🤖 Generated with [Claude Code](https://claude.com/claude-code)
