Fixes #5853
Fixes #2798

## What happens

Restoring some of the files makes the folders they need. Those folders are not in the restore set, so they are not restored themselves, and their metadata is not restored either. Each one was reported as a warning, "Creating missing folder ... for file ...", although making them is what the restore is expected to do.

For example, with `a/b/f.txt` and `a/c/g.txt` in a backup, restoring just those two files to a new folder warns twice, once for `b` and once for `c`, in both restore engines.

## The change

The folders that are in the restore set are made before any file is restored, by `RestoreHandler.CreateDirectoryStructureAsync`, in both engines. That step warns (`FolderCreateFailed`) when one cannot be made. So a folder that is still missing when a file is written is one that was not asked for, and that is the case the issue says should not warn.

Making such a folder is now logged at verbose level instead (`CreateMissingFolder`, same text). That is the level `CreateDirectoryStructureAsync` already uses when it makes a folder (`CreateFolder`). The places are the two in the new engine (`Restore/FileProcessor.cs`) and the four in the legacy engine (`RestoreHandler.cs`).

A folder that cannot be made is unchanged. The new engine still logs it as an error, and a folder in the restore set that cannot be made still warns (`FolderCreateFailed`).

## Red to green

`RestoreMissingFolderTests.RestoringSomeFilesMakesTheirFoldersWithoutWarnings` (new) restores the two files of the example above to a new folder, with and without `--restore-legacy`. It checks that the restore has no warnings, that both files are restored, and that a third file in `b` is not.

| Engine | Before | After |
|---|---|---|
| New | **red**: two `CreateMissingFolder` warnings (`b`, `c`) | green |
| Legacy | **red**: two `CreateMissingFolder` warnings (`b`, `c`) | green |

`RestoreHandlerTests.RestoreEmptyFileAsync` expected exactly one warning. Its comment said this warning comes from `--dont-compress-restore-paths` making the folders above the file. It now expects none, and the comment says why.

`RestoreHandlerTests`, `RestoreFileFailureTests`, `SymLinkTests`, `RestorePathTraversalTests` and `RestoreCallbackModuleTests` pass (59 tests, 3 skipped as not for this OS; Windows).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
