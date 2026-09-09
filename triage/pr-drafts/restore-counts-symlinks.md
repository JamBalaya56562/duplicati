## Summary

`IRestoreResults.RestoredSymlinks` has been part of the restore results since 2013 (added as `SymlinksRestored` in [d69667059](https://github.com/duplicati/duplicati/commit/d69667059), renamed in [965bd6d76](https://github.com/duplicati/duplicati/commit/965bd6d76)), and the old UI shows it on the restore result page. But neither restore engine ever added to it, so it was always 0.

A restored link is still counted as a file, as both engines do now (#7572 made the legacy engine match the new one), and it is now also counted in `RestoredSymlinks`. So `RestoredSymlinks` tells how many of the restored files are links. `RestoredFiles`, the "no files were restored" warnings and the usage report do not change.

In the new engine, `RestoreMetadataAsync` returns true when the link is made, but the other restore destinations (Office 365, Google Workspace, disk images) can also return true when they write metadata. So only an entry with the link blockset (`SYMLINK_BLOCKSET_ID`) is counted as a link.

Commit: [6f94215da2392fda84ac00aafa0ee106327e7c35](https://github.com/JamBalaya56562/duplicati/commit/6f94215da2392fda84ac00aafa0ee106327e7c35)

I could not find an issue for this.

## Testing

`RestoreSymlinkCountTests`, each run with `--restore-legacy=true` and `false`:

| test | before | after |
|---|---|---|
| `ARestoredLinkIsCounted` (added: `RestoredSymlinks` is 1) | **fail** in both engines: `Expected: 1 But was: 0` | pass |
| `OnlyTheLinkIsCountedAsALink` (new: a file and a link restored, `RestoredFiles` 2, `RestoredSymlinks` 1) | **fail** in both engines: `Expected: 1 But was: 0` | pass |
| `ALinkInPlaceIsCountedAsUnmodified` (added: `RestoredSymlinks` is 0) | pass | pass |

Related restore and link tests also pass (`RestoreHandlerTests`, `SymLinkTests`, `RestoreSymlink*Tests`, `RestoreDanglingSymlinkTests`, `RestoreJunctionTests`, `RestoreFileFailureTests`, `RestoreDryRunVerificationTests`, `FollowSymlink*Tests`, `Issue2171`, `IssueTests.Issue5825*`): 91 passed, 4 skipped, on Windows. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
