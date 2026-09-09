## Summary

A dry run restore writes no files. After the "restore", the legacy engine still went through every file it would have restored and opened it to check its hash. In a dry run to a folder that does not hold those files, every file failed with `Failed to restore file: "...". Error message was: Could not find file '...'`, and the restore reported errors. The new restore engine does not do this.

The legacy engine counts the restored files (`RestoredFiles`, `SizeOfRestoredFiles`) inside that same check. So even when no error occurred, a legacy dry run reported "Restored 0 (0 bytes) files", while the new engine reports the files it would restore.

The same happened with `--skip-restore-verification`: the files were restored, but the legacy engine reported "Restored 0 (0 bytes) files".

In a dry run, the legacy restore now skips the check. In a dry run and with `--skip-restore-verification`, it counts the files it restores, or would restore, with their lengths, as the new engine does.

## Testing

`RestoreDryRunVerificationTests.RestoreWithoutVerificationCountsTheFiles` restores the same two files with `--skip-restore-verification`, with both engines. It checks that the restore reports 2 files and their total size, and that the files are restored.

`RestoreDryRunVerificationTests.DryRunToAnEmptyFolderHasNoErrors` backs up two files, then runs a dry-run restore to an empty `--restore-path` with both engines. It checks three things:

- the restore has no errors;
- it reports 2 files and their total size;
- the folder stays empty.

Results:

- Windows, on master: the legacy case fails with two `RestoreFileFailed` errors (`Could not find file '...\restored\a.txt'` and `Could not find a part of the path '...\restored\sub\b.txt'`).
- Windows, with only the check skipped: the legacy case fails with `Expected: 2 But was: 0` for the file count.
- Windows, with only the dry-run part: the legacy case of `RestoreWithoutVerificationCountsTheFiles` fails with `Expected: 2 But was: 0`.
- Windows, with this change: 4/4 pass. The new-engine case passes in all three runs.
- The touched files build with no new warnings.
- CLI on Windows, dry-run restore to an empty folder: before, the legacy engine printed the errors (also seen on Linux in WSL). It now prints "Restored 1 (4 bytes) files", the same as the new engine, with no errors and nothing written.
- CLI on Windows, restore with `--skip-restore-verification`: both engines now print "Restored 1 (4 bytes) files", where the legacy engine printed 0 before.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
