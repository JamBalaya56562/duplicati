# Do not retry a dlist upload under a name that is taken

Opened as #7715 (2026-11-07). This is the body as posted.

If `fix/synthetic-filelist-after-interrupted-time` merges first, change `SyntheticFilelistRetryDoesNotTakeTheNameOfTheInterruptedDlistAsync` to `["number-of-retries"] = "2"`, `Has.Count.EqualTo(3)` and `interruptedPuts[2]`.

---

When an upload fails, `PutOperation` retries it under a new name (`RenameFileAfterError`). For block and index files the new name has a fresh random part. **A dlist name has no random part, only the time**, so the new name is simply one second later. Nothing checked that name: the file was uploaded under it, replacing whatever was there, and the database rename queued for it later renamed whichever volume held that name.

## How to reproduce

All cases are in `RenameAfterErrorTests`. The purge and repair tests move the older version close to the newer one in the local database and make the first upload fail with `DeterministicErrorBackend`.

**Purge** rewrites the older version one second after its old name. With two versions two seconds apart, that is one second before the newer version's name, so when the upload fails, the retry takes the newer version's name. On master:

```
dlist before: ...121323Z.dlist.zip, ...121325Z.dlist.zip
dlist after:  ...121325Z.dlist.zip, ...121327Z.dlist.zip
volume 6  ...121326Z Deleted     <- the newer version's old entry, renamed and deleted
volume 11 ...121324Z Uploading   <- the older version's rewrite, not on the destination
fileset 4 00:00:00 volume 12     <- a placeholder version
after a repair:    remote dlist contents: b.txt c.txt (one file)
after a recreate:  v0 only
```

The purge reported success. The older version's dlist is gone from the destination, and a database recreated from the destination has one version instead of two.

**Repair** of a missing older dlist reuses its original name (#7573). With two versions one second apart, the retry takes the newer version's name, and the repair logs `UNIQUE constraint failed: Remotevolume.Name`. The next repair then fails to verify the newer dlist.

**Synthetic filelists** hit it too. A backup whose dlist upload fails, and fails again under the next second (`number-of-retries=1`), leaves its fileset (time T) with a dlist named T+1 and a placeholder named T. The next backup's verification drops the placeholder, so the synthetic dlist is named T, and the retry of a failed synthetic upload is T+1, the interrupted backup's dlist name. On master, the backup that should finish the interrupted one fails:

```
RemoteListVerificationException: The missing remote volume duplicati-...Z.dlist.zip is in uploading state and strict mode is on
```

## The change

`FilesetVolumeWriter` gets an `IsRemoteNameTaken` check. Backup, synthetic filelists, purge and the repair paths set it to look the name up in the database's remote volumes (`FilesetVolumeWriter.NameTakenIn`). `BackendManager.PutAsync` hands it to the `PutOperation`. When the rename after a failed upload picks a name that is taken, it moves on one second at a time until the name is free, as `ProbeUnusedFilenameNameAsync` does.

- **No free name in 60 tries**: the retry fails with `FailedToFindUnusedFilename`, the same limit and error as `ProbeUnusedFilenameNameAsync`. The upload fails, and nothing is overwritten.
- **A name that is only on the destination**: not checked, same as `ProbeUnusedFilenameNameAsync`. The check reads the database, not a listing of the destination. A file the database does not know is an extra file, which the next verification removes anyway.
- Block and index files are unchanged, because their names have a random part.

## Testing

`RenameAfterErrorTests` on Windows, against the current master (the test file alone) and this branch:

| test | master | this branch |
|---|---|---|
| `PurgeRetryDoesNotTakeTheNameOfTheNewerDlistAsync` | **fail**: one dlist left | pass |
| `RepairRetryDoesNotTakeTheNameOfTheNewerDlistAsync(1)` | **fail**: `UNIQUE constraint failed: Remotevolume.Name` | pass |
| `RepairRetryDoesNotTakeTheNameOfTheNewerDlistAsync(2)` | pass | pass |
| `SyntheticFilelistRetryDoesNotTakeTheNameOfTheInterruptedDlistAsync` | **fail**: `RemoteListVerificationException` | pass |

`RenameAfterErrorTests`, `RepairFilesetTimestampTests`, `RepairHandlerTests.RepairMissingDlistVolumeAsync` and `PurgeTesting` together: 12 passed on this branch. No new warnings in the changed files.

## Not changed

- After the retry, a dlist that does not record its fileset time is read back by a recreate at the time of its new name. That is one or more seconds after the version's time. The order is kept. The tests compare versions, not exact times, for that reason.
- The placeholder version a rename leaves behind (time 0, `LocalDatabase.RenameRemoteFileAsync`) stays until the next verification, as before.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
