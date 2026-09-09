Branch: `fix/sync-job-delete-ignores-remote-files` (origin), commit [f31c9a805f2949370754ffa328396973282344ee](https://github.com/JamBalaya56562/duplicati/commit/f31c9a805f2949370754ffa328396973282344ee), on master 98067e41a555.
Independent of `fix/sync-job-rejects-backup-operations`. Both add a test after `SyncJobReportsLastRunAndLogs_Async` in `ServerApiIntegrationTests.cs`, so whichever lands second needs a rebase.
No upstream issue found (searched "delete remote files sync", "delete sync job", "sync job delete" on 2026-10-22).

Title: Keep the synced copy when deleting a sync job with "delete remote files"

## Summary

Found while looking into https://forum.duplicati.com/t/22782 (sync jobs on the Restore page). Deleting a sync job with "Delete remote files" checked fails, and the job is not deleted. `DeleteAllRemoteFilesAsync` goes through `Controller.SetupCommonOptions`, which opens the job database as a backup `LocalDatabase`. A sync job's database (`LocalSyncDatabase`) has a different schema:

```
SQL could not be executed:
INSERT INTO "FilesetEntry_Temp" SELECT "FilesetID", "FileID", 0 FROM "FilesetEntry"
Error: SQLite Error 1: 'no such table: FilesetEntry'.
```

The exception is thrown before `DeleteBackup`, so the job stays.

For a sync job, the delete task now ignores `delete-remote-files`. It still deletes the job and, if asked, the local database, and it keeps the files at the destination. Reasons:
- "Delete remote files" only removes Duplicati backup volumes (`dblock`/`dindex`/`dlist` with the job's prefix). A sync destination holds the copied files and no volumes, so the option has nothing to remove there.
- If the synced source is itself a backup folder, the mirror contains files that look like volumes. Deleting them would destroy the user's copy of that backup.

The web UI will hide the option for sync jobs in a separate ngclient change.

## Testing

- New `ServerApiIntegrationTests.SyncJobCanBeDeletedWithItsRemoteFiles_Async`: runs a sync job whose source includes a file named like a backup volume (`duplicati-20260101T000000Z.dlist.zip`). It then deletes the job with `delete-remote-files=true&delete-local-db=true` and expects the task to complete, the job to be gone (404), and both synced files to remain at the destination. Before the fix, the delete task ended as `Failed` with the SQL error above.
- With the fix, the new test and `SyncJobReportsLastRunAndLogs_Async` pass. The backup-job path is unchanged apart from the added `OperationType` check; no existing server test covers deleting a backup job with its remote files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
