When only a symbolic link is restored with `--restore-legacy=true`, the link is restored, but the restore ends with:

> Restore completed without errors but no files or folders were restored

The legacy engine makes the link when it applies the stored metadata (`ApplyStoredMetadataAsync`), and nothing counted it. The new engine counts a link as a file: restored when the link was made, unmodified when it was already in place. The legacy engine now does the same. To know whether an entry is a link, the metadata is deserialized once in `ApplyStoredMetadataAsync`. The public `ApplyMetadataAsync(…, Stream, …)` used by the new engine behaves the same.

### Tests

`RestoreSymlinkCountTests` backs up a file and a link to it, then restores only the link with both engines. It covers two cases: the link is missing, and the link is already in place. It checks that the link is there, that there is no `NoFilesOrFoldersRestored` warning, and the counts (`RestoredFiles` = 1, or `UnmodifiedFiles` = 1).

- Windows, before the fix: both `(True)` cases fail with `[Warning-…RestoreHandler-NoFilesOrFoldersRestored]: Restore completed without errors but no files or folders were restored`. The `(False)` cases pass.
- After the fix: 4/4 pass. `SymLinkTests`, `RestoreSymlinkOverExistingDataTests`, `RestoreHandlerTests`, `RestoreFileFailureTests`, `RestorePathTraversalTests` and the legacy cases of `IssueTests` (5825, 3340, 5826, 6068) pass: 81 passed, 3 skipped (Linux-only).
- `RestoreHandlerTests.RestoreVolumeCacheDiskPressureAsync` hits its 120 s timeout on this machine. It fails the same way on master without this change.
- No new build warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
