## What happens

Two problems, both in restoring symbolic links to the original location.

### 1. Data in place of a link is removed

To restore a symbolic link, `FileRestoreDestinationProvider.WriteMetadata` makes the link. Before that, it removes whatever is at that path: a file with `FileDelete`, and a folder with `DirectoryDelete(path, true)`.

If the link was replaced by real data after the backup, a restore to the original location removes that data, with no warning. This happens even without `--overwrite`, and a folder is removed with everything in it, including files that are in no backup.

Measured on Linux, and on Windows with symbolic links and junctions. In every case the restore reported no warning and no error:

| At restore time, in place of the link | Restore | Before |
|---|---|---|
| a folder holding `mine.txt` and `sub/mine2.txt` | `--overwrite=false` | folder and contents removed, link made |
| the same | `--overwrite=true` | folder and contents removed, link made |
| the same | only the link selected | folder and contents removed, link made |
| a file | `--overwrite=false` | file removed, link made |

### 2. A source that is itself a link

When a source is itself a symbolic link to a folder, the backup follows it, so its files are stored below the link. The link itself is stored as a link, not as a folder.

The `FileProcessor` holds folder metadata back until every file is restored (`RendezvousBeforeProcessingFolderMetadataAsync`), but it does not hold links back. A link is handled like any other file, in parallel with the rest.

- **Everything still in place.** Every in-place restore warns once per file below the link (`MetadataWriteFailed`, "Could not find a part of the path"), and those files do not get their timestamps back. Logging the order on Windows showed why: four processors started together, and the link was removed and made again (a 2 ms gap) at the same moment the metadata of the files below it was written.
- **A new machine, with neither the link nor its target present.** The files are restored into a folder at the link's path. Making the link then removed that folder together with the files. The restore reported only warnings, with no error, and left a link that points to nothing. All files were lost, on both Linux and Windows, with or without `--overwrite`.

## The change

**What is in place of the link** is replaced only when nothing is lost, or when the user asked for it:

- **A link that already points where it should:** left as it is. It is not removed and made again, so its path never goes missing.
- **Any other link:** replaced, as before. What it points to is not touched.
- **An empty folder:** replaced, as before.
- **A folder with files in it:** never removed, with or without `--overwrite`. A restore otherwise leaves alone files that are not in the backup. The link is not made, and a warning (`SymlinkPlaceTakenByFolder`) says why. When this restore put entries below the link, as for a source that is itself a link, the folder holds what was restored, and that is logged as information (`SymlinkRestoredAsFolder`) instead.
- **A file:** replaced with `--overwrite`. Without `--overwrite` it is kept and the link is not made, with a warning (`SymlinkPlaceTakenByFile`). A regular file in the same place would instead be restored under a new name.

The provider receives `--overwrite` through a new constructor argument, which every caller passes.

**Links to folders with entries restored below them are restored last:**

- `FileLister` finds the links to folders that have other entries restored below them (`FindLinksWithRestoredEntriesBelow`), flags them with `HasRestoredEntriesBelow`, and sends them last, after the files, the folders and the alternate data streams, deeper ones first. Other links stay with the files, so they are in place before the metadata of their folder is restored; made after it, they set the folder's modification time to the time of the restore.
- `FileProcessor` holds them back until every other processor has reached them or is done, so nothing else is being restored when a link is made, and makes them one at a time, as one may lie below another. Holding them back only until every file is restored, as for folder metadata, is not enough: a link that replaces another one removes its path for a moment, and the metadata of a folder below it, written at the same time, then fails.

The ordering is done in the lister as well, so it also holds with a single processor. As a result, the link is always judged with the files already in place. On a new machine, the restored files stay as a folder, and that is logged as information rather than as a warning.

With `--overwrite`, a folder with files in it is kept rather than replaced.

## Checked

The third commit, by @kenkendk, adds `ALinkDoesNotChangeTheRestoredTimestampOfItsFolder` and `AStaleLinkWithAFolderRestoredBelowItIsReplacedWithoutWarnings`, and the new-machine test now expects no warning and the `SymlinkRestoredAsFolder` message. All checks pass on it. The rest of this section is from before that commit.

`RestoreSymlinkOverExistingDataTests`, on Linux, against master, then the first commit of this branch, then the second:

| Test | master | 1st commit | 2nd commit |
|---|---|---|---|
| `AFolderInPlaceOfALinkIsNotRemovedWithoutOverwrite` | fails, folder removed | passes | passes |
| `AFolderInPlaceOfALinkIsNotRemovedWithOverwrite` | fails, folder removed | passes | passes |
| `AFileInPlaceOfALinkIsKeptWithoutOverwrite` | fails, file replaced | passes | passes |
| `TheFilesOfASourceThatIsALinkAreKeptWhenRestoredToANewMachine` (with and without `--overwrite`) | fails, files lost | passes | passes |
| `ASourceThatIsALinkIsRestoredInPlaceWithoutWarnings` | fails, a warning per file | fails, a warning per file | passes |
| `AFileInPlaceOfALinkIsReplacedWithOverwrite` | passes | passes | passes |
| `AnEmptyFolderInPlaceOfALinkIsReplaced` | passes | passes | passes |
| `ALinkThatIsStillThereIsRestoredWithoutTouchingItsTarget` | passes | passes | passes |

A note on the new-machine test: with the first commit it depends on the order the processors happen to take. It passed in these runs, but only the second commit makes that order certain.

On Windows, all of these pass with the second commit. The warnings that the first commit leaves were seen there with a probe.

The second commit first held links back only until every file was restored. A test that replaces a link below which a folder is restored (in a follow-up PR for junctions) then failed in 7 of 12 runs on Windows, with `MetadataWriteFailed` for that folder. With links sent last and held back until nothing else is restored, it passed 20 of 20. After that change, the tests above, `SymLinkTests`, `AlternateDataStreamTests`, `RestoreHandlerTests` (including the stopped and aborted restores) and `RestoreFileFailureTests` pass on Windows. The Linux runs in the table are from before it.

These existing test classes pass before and after:

- `SymLinkTests`
- `RestorePathTraversalTests` (including the three symbolic link tests that run only on Linux)
- `AlternateDataStreamTests` (Windows)
- `RestoreCallbackModuleTests`
- `SourceProviderOptionValidationTests`

The tests are skipped where symbolic links cannot be made.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

