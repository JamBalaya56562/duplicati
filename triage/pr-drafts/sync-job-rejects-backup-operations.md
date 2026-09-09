Branch: `fix/sync-job-rejects-backup-operations` (origin), commit [f80a81a1d271c4585180185b590824ad2b802906](https://github.com/JamBalaya56562/duplicati/commit/f80a81a1d271c4585180185b590824ad2b802906), on master 98067e41a555.
No upstream issue found (searched "sync restore", "sync job restore", "sync job SQL", "sync job list filesets", and the 30 newest "sync" issues on 2026-10-22).

Title: Refuse restore and other backup operations on sync jobs

## Summary

Reported in https://forum.duplicati.com/t/22782 (2.4.0.1): once a local-to-local sync job has run, picking it on the Restore page fails with SQL errors ("could not create index", "database could not be upgraded").

A sync job copies files to the destination without keeping versions, and its local database (`LocalSyncDatabase`) has its own schema. Every operation other than running the sync goes through `Controller.SetupCommonOptions`, which opens the job database as a backup `LocalDatabase` and runs the backup schema upgrade on it. That fails:

```
SQL could not be executed:
INSERT INTO "FilesetEntry_Temp" SELECT "FilesetID", "FileID", 0 FROM "FilesetEntry"
Error: SQLite Error 1: 'no such table: FilesetEntry'.
The database was not upgraded.
```

The server now refuses these operations when the task is created in `Runner.CreateTask`, which every API endpoint goes through. Nothing is queued and the sync job is not marked as failed. A sync job still supports running (`BackupOrSync`) and deleting the job (`Delete`). Every other operation is refused: restore, list, version and folder listing, search, repair, verify, compact, vacuum, list-remote, bug report, delete versions, and broken/purge files. All of them would open the sync database as a backup database.

The error is a `UserInformationException` with help ID `SyncJobNotSupported`:
- v1, for example `POST /api/v1/backup/{id}/restore`: HTTP 400 `{"Error": "...", "Code": 400, "HelpId": "SyncJobNotSupported"}`
- v2, for example `POST /api/v2/backup/list-filesets`: HTTP 200 `{"Success": false, "Error": "...", "StatusCode": "SyncJobNotSupported"}`

Hiding sync jobs on the Restore page is a separate ngclient change.

## Testing

- New `ServerApiIntegrationTests.SyncJobRefusesVersionListingAndRestore_Async`: creates and runs a sync job, then calls `list-filesets` (v2) and `restore` (v1) and expects both to be refused with `SyncJobNotSupported`. It then runs the sync again to show the job still works. Before the fix, `list-filesets` returned HTTP 500 and the server logged the SQL error above.
- With the fix, these pass: the new test, `ServerBackupLifecycle_Async` (backup restore through the API), `ServerRepairUpdateListsRootPaths_Async` (backup `list-filesets`/`list-folder`/repair-update), and `SyncJobReportsLastRunAndLogs_Async`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
