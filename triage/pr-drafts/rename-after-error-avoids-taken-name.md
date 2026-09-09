# PR draft: fix/rename-after-error-avoids-taken-name

Branch: `fix/rename-after-error-avoids-taken-name` on origin (JamBalaya56562/duplicati), one commit
[f033f979c2b429d12b0d8efe695117b9489b3fe4](https://github.com/JamBalaya56562/duplicati/commit/f033f979c2b429d12b0d8efe695117b9489b3fe4) on master 7cdde1585522.
Not stacked on the other repair branches.

Upstream issues searched: "dlist overwritten retry", "Renaming dlist upload", "UNIQUE constraint failed
Remotevolume Name", "purge missing dlist after upload error", "dlist rename retry". No match.
duplicati/duplicati#3590 (UNIQUE constraint on Google Drive) is a duplicated dindex, unrelated.

## Merging with the other repair branches

Merge order: `fix/repair-dlist-keeps-order` (#7529), then `fix/repair-dlist-reuses-name`, then this one.
Any order works, but each later one conflicts in the same hunk of `RepairHandler.cs`.

- Against keeps-order alone: no conflict (the `{ IsRemoteNameTaken = ... }` lines merge cleanly).
- Against reuses-name: one conflict in the dlist loop. The resolution is the one in the reuses-name draft,
  **and the writer that reuses the original name has to get the check too**:

  ```csharp
  var sameNameWriter = newEntry = new FilesetVolumeWriter(m_options, nameTime) { IsRemoteNameTaken = FilesetVolumeWriter.NameTakenIn(db) };
  ```

  Without that, `RepairRetryDoesNotTakeTheNameOfTheNewerDlistAsync(1)` fails in the merged tree:
  the reused name is one second before the newer dlist, the retry takes the newer one's name, and a
  recreate is left with one version. Measured on a temporary merge of all three branches: 14 of 14
  pass with the line, and (1) fails without it.

## Title

Do not retry a dlist upload under a name that is taken

## Body

When an upload fails, `PutOperation` retries it under a new name (`RenameFileAfterError`). For block and
index files the new name has a fresh random part. **A dlist name has no random part, only the time**, so
the new name is simply one second later. Nothing checked that name: the file was uploaded under it,
replacing whatever was there, and the database rename queued for it later renamed whichever volume held
that name.

### How to reproduce

Two versions two seconds apart, and one failed upload. Both cases are in `RenameAfterErrorTests`, which
moves the older version to two seconds before the newer in the local database and makes the first upload
fail with `DeterministicErrorBackend`.

**Purge** rewrites the older version one second after its old name, one second before the newer
version's name. When that upload fails, the retry takes the newer version's name. On master:

```
dlist before: ...121323Z.dlist.zip, ...121325Z.dlist.zip
dlist after:  ...121325Z.dlist.zip, ...121327Z.dlist.zip
volume 6  ...121326Z Deleted     <- the newer version's old entry, renamed and deleted
volume 11 ...121324Z Uploading   <- the older version's rewrite, not on the destination
fileset 4 00:00:00 volume 12     <- a placeholder version
after a repair:    remote dlist contents: b.txt c.txt (one file)
after a recreate:  v0 only
```

The purge reported success. The older version's dlist is gone from the destination, and a database
recreated from the destination has one version instead of two.

**Repair** replacing a missing older dlist one second after its old name does the same. The retry
overwrites the newer version's dlist with the older one's contents. The repair logs
`UNIQUE constraint failed: Remotevolume.Name`, the next repair reports that the newer dlist has the wrong
size, and a recreated database has lost the newer version.

The same rename is used for the dlist of a normal backup and for synthetic filelists. There the next
second is normally free, because the file is the newest one. Clock skew aside, they are not expected to
hit this. They get the same check anyway.

### The change

`FilesetVolumeWriter` gets an `IsRemoteNameTaken` check. Backup, synthetic filelists, purge and both repair
paths set it to look the name up in the database's remote volumes (`FilesetVolumeWriter.NameTakenIn`).
`BackendManager.PutAsync` hands it to the `PutOperation`. When the rename after a failed upload picks a
name that is taken, it moves on one second at a time until the name is free, as
`ProbeUnusedFilenameNameAsync` does.

- **No free name in 60 tries**: the retry fails with `FailedToFindUnusedFilename`, the same limit and error
  as `ProbeUnusedFilenameNameAsync`. The upload fails, and nothing is overwritten.
- **A name that is only on the destination**: not checked, same as `ProbeUnusedFilenameNameAsync`. The
  check reads the database, not a listing of the destination. A file the database does not know is an
  extra file, which the next verification removes anyway.
- Block and index files are unchanged, because their names have a random part.

### Tests

| test | master | this branch |
|---|---|---|
| `PurgeRetryDoesNotTakeTheNameOfTheNewerDlistAsync` | **fail**: one dlist left, a recreate has one version | pass |
| `RepairRetryDoesNotTakeTheNameOfTheNewerDlistAsync(2)` | **fail**: `UNIQUE constraint failed: Remotevolume.Name`, a recreate has one version | pass |
| `RepairRetryDoesNotTakeTheNameOfTheNewerDlistAsync(1)` | not run on master (expected to pass: master names the replacement two seconds later, so the retry name is free) | pass. With `fix/repair-dlist-reuses-name` it covers the reused name, see above |

Also passing: `PurgeTesting`, `CompactDisruptionTests`, `RepairFilesetTimestampTests`,
`RepairHandlerTests.RepairMissingDlistVolumeAsync`, `DisruptionTests.FilesetFilesAsync`.

### Not changed

- After the retry, a dlist that does not record its fileset time (the purge one) is read back by a recreate
  at the time of its new name. That is one or more seconds after the version's time. The order is kept.
  The tests compare versions, not exact times, for that reason.
- The placeholder version a rename leaves behind (time 0, `LocalDatabase.RenameRemoteFileAsync`) stays
  until the next verification, as before.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

## Update 2026-10-23: synthetic filelist test added

The branch is now two commits on master 922a7c73:
[99c681f5a1fd66d3af0c3c5a75609db64d0de94e](https://github.com/JamBalaya56562/duplicati/commit/99c681f5a1fd66d3af0c3c5a75609db64d0de94e) (the fix) and
[268fd5b4d1eb5fa652428bf2aa24bc76327993d3](https://github.com/JamBalaya56562/duplicati/commit/268fd5b4d1eb5fa652428bf2aa24bc76327993d3) (the test).

**Correction to the body**: synthetic filelists do hit the clash without clock skew. A backup whose dlist upload
fails, and fails again under the next second (`number-of-retries=1`), leaves its fileset (time T) with a dlist named
T+1 and a placeholder named T. The next backup's verification drops the placeholder, so the synthetic dlist is
named T, and the retry of a failed synthetic upload is T+1, the interrupted backup's dlist name. Replace "There the
next second is normally free ... They get the same check anyway." with that.

New test `RenameAfterErrorTests.SyntheticFilelistRetryDoesNotTakeTheNameOfTheInterruptedDlistAsync`. It asserts the
precondition (synthetic first name + 1 s == the interrupted dlist name), that the backup succeeds, two versions after
a repair, and the same versions after a recreate.

On master (library files of 922a7c73, same test):

```
uploads: ...094509Z.dlist.zip, ...094511Z.dlist.zip, ...094515Z.dlist.zip
error: RemoteListVerificationException: The missing remote volume duplicati-20261023T094509Z.dlist.zip is in uploading state and strict mode is on
volume 1 ...094511Z Uploaded     <- the interrupted backup's entry, renamed
volume 4 ...094509Z Uploading    <- not on the destination
volume 5 ...094510Z Deleting
fileset 2 09:45:09 volume 4, fileset 3 00:00:00 volume 5 (placeholder)
```

The backup that should finish the interrupted one fails. On this branch: pass (all 4 `RenameAfterErrorTests`).

| test | master | this branch |
|---|---|---|
| `SyntheticFilelistRetryDoesNotTakeTheNameOfTheInterruptedDlistAsync` | **fail**: the backup fails with `RemoteListVerificationException` | pass |

## Interaction with fix/synthetic-filelist-after-interrupted-time (2026-10-24)

That branch names the synthetic dlist from T+1 instead of T. If it is merged first, change
`SyntheticFilelistRetryDoesNotTakeTheNameOfTheInterruptedDlistAsync` to `["number-of-retries"] = "2"`,
`Has.Count.EqualTo(3)` and `interruptedPuts[2]` (checked on a temporary merge: passes, and fails with the rename
check removed). The correction to the body above then reads: the dlist upload failing three times instead of twice.
