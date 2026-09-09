## Summary

In #7543 a source drive failed. Its mount point still existed, but listing it failed with `EIO`, and the backup only logged warnings (`MetadataProcessFailed`, `PathProcessingErrorEnumerate`). Each backup then stored a version without any of the files on that drive, and after a few days the retention policy had removed the versions that still had them.

A source that does not exist is already handled before the backup starts: it is a warning that skips it, an error with `--abort-if-source-missing`, or silent with `--allow-missing-source`. A source folder that exists but cannot be read went past that check, because it only looks at whether the path exists (and lists the folder only for `--prevent-empty-source`).

The check now also lists the folder (one entry is enough), unless `--allow-missing-source` is set:

- if listing fails with an `IOException` (a failed or disconnected drive), the backup is aborted with the new `SourceUnreadable` error, which names the folder and the error;
- if access is denied, it is aborted with the existing `SourceUnauthorized` error, which `--prevent-empty-source` already used.

No version is created in either case. With `--allow-missing-source` the backup continues as before, and its help now says that it also covers a source folder that cannot be read. Folders below the source that cannot be read are not affected; they are still warnings.

This changes what happens for a source folder whose permissions do not allow listing it: before, it was backed up as empty with a warning; now the backup stops. I think that is the same case as #7543 from the user's point of view, but it can be limited to `IOException` if you prefer.

Fixes #7543

Commit: [3df0f8b273a6a89f67b2323745b8515354f562c4](https://github.com/JamBalaya56562/duplicati/commit/3df0f8b273a6a89f67b2323745b8515354f562c4)

## Testing

New `UnreadableSourceTests`. Each test backs up a folder with five files, then breaks the folder: on Windows it becomes a junction to a folder that is gone (it exists, and listing it fails with `DirectoryNotFoundException`, an `IOException`); on Linux its permissions are removed (listing fails with `UnauthorizedAccessException`).

| test | before | after |
|---|---|---|
| `ASourceFolderThatCannotBeListedStopsTheBackup` | **fail** on Windows and Linux: the backup completes, no exception | pass: `SourceUnreadable` (Windows) / `SourceUnauthorized` (Linux), still one dlist |
| `AllowMissingSourceStillBacksUpWithoutIt` | pass | pass |

Run on Windows and on Linux (WSL, ext4, as a normal user). `UnreadableSourceTests`, `PreventEmptySourceTest` and `MissingSourceTest`: 8 passed on both. `Duplicati.slnx` builds with no new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
