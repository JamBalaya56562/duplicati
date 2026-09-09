To browse a backup for a direct restore, ngclient creates a temporary job and rebuilds its database with the paths only (`POST /api/v1/backup/{id}/repairupdate` with `only_paths`). A restore with that same job failed:

```
Found 2 remote files that are not recorded in local storage. This can be caused by having two backups sharing a destination folder which is not supported. ...
```

No file was restored. This happens on the same system too, not only for a backup from another system (found while looking into duplicati/ngclient#449).

## Cause

`RecreateDatabaseHandler.RunUpdateAsync`, behind `repairupdate`, marks the database as partially recreated. With `repair-only-paths`, it records the filesets and paths, but not the block volumes.

`RestoreHandler.RunSingleVersionRestoreAsync` used any local database that exists. With this one, the check of the remote list before the restore (`FilelistProcessor.VerifyRemoteListAsync`) found the dblock and dindex files unknown:

```
Extra unknown file: duplicati-...dblock.zip
Extra unknown file: duplicati-...dindex.zip
```

ngclient does not hit this, because it restores a temporary job through `copytotemp`, a copy without a database (`restore-flow.state.ts`). A client that calls the restore of the same job does.

## The change

A restore now treats a partially recreated database like a missing one. It closes it and builds a temporary database for the restore, which is the existing path when there is no local database. The `--restore-all-files` restore goes through the same path for each version.

A restore with a database that another operation left partially recreated (for example a repair of only some versions) now builds a temporary database as well. This is slower, and gives the same result as a restore without a local database.

## Testing

New `RestoreFromPartiallyRecreatedDatabaseTests.AFolderIsRestoredWithADatabaseRebuiltWithThePathsOnlyAsync`, for the new and the legacy restore. It makes a backup, deletes the database and rebuilds it with `UpdateDatabaseWithVersionsAsync` and `repair-only-paths`, as `repairupdate` does, then restores one folder.

| | master | this branch |
|---|---|---|
| `(False)` | **fail**: `RemoteListVerificationException: Found 2 remote files that are not recorded in local storage` | pass: only `payload.txt` is restored, with its content |
| `(True)` (legacy) | **fail**: the same | pass |

With `RestoreHandlerTests`, `RestoreAllFilesTests` and the recreate tests, 49 tests pass on Windows. No new warnings in the changed files.

I also ran a server built from this branch on Windows, with an isolated data folder and the backups from duplicati/ngclient#449, made by 2.4.1.101 Canary on Windows and on Linux. The requests were the same as ngclient's: a temporary job, `list-filesets`, `repairupdate` with `only_paths`, `list-folder`. Then I restored `Documents\*` with the same job. "Without this change" is a server with the restore code of master, built from the branch of #7776, which does not touch the restore:

| backup | without this change | this branch |
|---|---|---|
| Windows | Failed, "Found 2 remote files ..." | Completed, only `payload.txt`, with the content of the source file |
| Linux | Failed, the same | Completed, the same |

The server log shows the new path: `The local database was only partially recreated, building a temporary database`.

Not tried on Linux or macOS.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
