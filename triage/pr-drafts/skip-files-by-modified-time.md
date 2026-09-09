Title: Add options to skip files by their modification time

There was no way to back up only the files changed after a point in time, or only the files that have not changed for a while (#1925).

## The change

- New options `--skip-files-modified-before` and `--skip-files-modified-after`. The value is a date, or an interval back from now such as `1W`.
- A skipped file is not in the new version, as with `--skip-files-larger-than` (`FilePreFilterProcess`). A file whose modification time cannot be read is kept. test-filters reports the files that the limits skip.
- A limit given relative to now moves with every run, so a file can cross it without being changed:
  - The USN journal only lists changed files, so the limits are part of its configuration. A moving limit makes the backup scan the files again; a date keeps using the journal.
  - `--changed-files` and a source that tracks its own changes copy the other files from the previous version. They refuse a moving limit (`MovingTimeLimitWithChangedFiles`, `MovingTimeLimitWithChangeTrackingSource`). A date works with them.

## Testing

- `BackupModifiedTimeFilterTests`, 6 tests:
  - Without a limit, all files are backed up. A date and an interval each leave out the right files, and a file from the previous version is left out too. 3 of these fail without the change (the options are unknown).
  - A moving limit is refused with `--changed-files`, and a date works with it. Without the check, the moving cases went on instead of stopping.
- `ChangeTrackingSourceProviderTests`: a moving limit is refused with a change tracking source, and a date passes.

Not tried: the USN journal path, which needs a real volume and administrator rights.

Fixes #1925

🤖 Generated with [Claude Code](https://claude.com/claude-code)
