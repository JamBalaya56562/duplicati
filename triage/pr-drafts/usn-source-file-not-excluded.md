Fixes #5175

## What happens

With the USN journal (`--usn-policy`), a backup after the first one takes the files that changed from the journal. `UsnJournalService.FilterExcludedFiles` checks each of them against the filters, and then checks the folders above it (`IsFolderOrAncestorsExcluded`), so that a file below an excluded folder is left out. The walk up stops at a source, because the sources are in its cache as included.

A source that is a single file is not a folder above itself, so the walk never reached it and went on up to the drive root. The root is usually hidden and a system folder (`C:\` here has `Hidden, System, Directory`). With hidden or system files excluded, the root was excluded, so the file was left out. As the issue shows, this happened from the second backup on: the backup then holds no files, and the verbose log says `Excluding path due to attribute filter: C:\`.

A full scan does not do this: a source is never excluded by the folders above it.

## The change

In `FilterExcludedFiles`, a changed file that is itself a source (included in the cache, as the sources are) is not checked against the folders above it. The file itself is still checked against the filters, as before. Files below a folder source are checked as before.

## Red to green

Reading the USN journal needs an elevated process, so there are two tests.

`UsnSourceFileBackupTests.ASourceFileIsKeptWhenHiddenAndSystemFilesAreExcluded` (new) is the case from the issue. It backs up a single file as the source with `--usn-policy=required`, `--snapshot-policy=off` and `--exclude-files-attributes=Hidden,System`, changes the file, and backs up again. It is ignored when the process is not elevated. Run from an elevated shell on Windows 11, with `C:\` hidden and a system folder:

| | Before | After |
|---|---|---|
| Second backup | **red**: `NoFilesInBackup`, "The backup completed but no files were processed" | the file is kept as modified, and listed in the latest version |

`UsnSourceFileFilterTests` (new) calls `FilterExcludedFiles` directly, with a snapshot that knows a few entries and the cache seeded with the sources as `GetModifiedSources` seeds it. It needs no elevation:

| Test | Before | After |
|---|---|---|
| `AChangedFileThatIsASourceIsKept` (drive root hidden and system) | **red**: no files kept | kept |
| `AChangedFileInAFolderSourceIsKept` | kept | kept |
| `AChangedFileBelowAnExcludedFolderIsLeftOut` (a hidden folder below a folder source) | left out | left out |

`Issue4951`, which also backs up with the USN journal, passes from the same elevated shell.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
