## Summary

When a stop reaches a backup before it starts processing files, `BackupHandler` skips the main operation (the `ProgressRendevouzAsync` check before `RunMainOperationAsync` returns false), but the fileset was then finished as if the backup had run:

- `UpdateChangeStatisticsAsync` compared the empty fileset with the previous version, so every file counted as deleted (`DeletedFiles` = all of them).
- Because of those "changes", `UploadRealFilelist` uploaded the empty fileset, and it became the latest version.
- `ExaminedFiles` was 0 and `PartialBackup` was not set (that flag is only set when the file enumeration itself sees the stop), so the backup also warned `NoFilesInBackup`: "The backup completed but no files were processed. This is likely a misconfiguration".
- The fileset was not marked as a full backup in the local database, but the dlist said it was, so after a recreate it would be an empty full version.

When the main operation does not run, `UploadRealFilelist` now skips the change statistics and drops the fileset the same way as for a backup without changes. No version is created, no files are reported as deleted, and the `NoFilesInBackup` warning is not given (it only applies to an uploaded fileset). An information message `StoppedBeforeProcessing` says why.

A stop that arrives while the files are being processed is not changed: that backup is still stored as a partial version, as before.

Fixes #7628

Commit: [824c553680fb57fc9ccb29e40a55af2de46c0f4e](https://github.com/JamBalaya56562/duplicati/commit/824c553680fb57fc9ccb29e40a55af2de46c0f4e)

## Testing

New test `EarlyStopRequestTests.AStopBeforeAnyFileIsProcessedCreatesNoVersion`: a backup of 20 files, then a backup with a stop asked for before it starts, then a normal backup.

- Before (master): fails with the `NoFilesInBackup` warning. A probe of the same steps on master showed `Interrupted=True ExaminedFiles=0 PartialBackup=False DeletedFiles=20`, a second dlist (861 bytes against 2317 for the first), and `ListAsync` returning an empty version v0 next to the 20-file v1.
- After: passes. The stopped backup is interrupted, has no warning, reports no deleted files, and uploads no dlist; the list still has only the first version with 20 files; the next backup adds the new file with no errors, warnings or deleted files.

`EarlyStopRequestTests`, `DisruptionTests`, `Issue6366`, `Issue6820`, `Issue1698`, `DryRunTests` and `ChangeTrackingSourceProviderTests`: 86 passed. `Duplicati.slnx` builds with no new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
