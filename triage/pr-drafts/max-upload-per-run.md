A destination with a daily or monthly transfer cap rejects the uploads once a run goes over it, and nothing can keep a run under it: `--throttle-upload` limits the speed, not the amount (#7264).

## The change

New option `--max-upload-per-run` (a size, MB when no unit is given, no limit by default). It applies to backups only.

- Once the uploads of a backup reach the size, the backup logs the warning `MaxUploadPerRunReached` and stops after the current file, the same way as a stop from the user (`TaskControl.Stop()`).
- The run is saved as a partial backup, and the next run backs up the files it did not reach.
- The volumes being made or uploaded, and the dlist, are still uploaded, so a run can upload somewhat more than the limit. The help says so.
- The count is the sum of the completed uploads of `BackendWriter`, including uploads during the check before the backup. For this `IBackendWriter` has a new `UploadCompleted`. `BackendWriter` is its only implementation.

The name, and stopping after the current file instead of in the middle of a volume, are my choices. I am happy to change them.

## Testing

New `MaxUploadPerRunTests`, 7 tests: 4 for reading the option, a backup stops at the limit, repeated runs with the limit end up with all 40 files, and no stop without the option. With the stop call removed, 2 of them fail (no partial backup, one run uploads everything). All 7 pass here.

With `EarlyStopRequestTests`, `OptionDescriptionFormatTests`, `OptionsTests`, `ModuleOptionTypeTests` and `DryRunTests`, 51 tests pass. No new warnings in the changed files.

Not tried: a real destination with a transfer cap, and how the option shows in the new UI.

Fixes #7264

🤖 Generated with [Claude Code](https://claude.com/claude-code)
