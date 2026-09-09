# PR draft: fix/rename-without-placeholder-fileset

Branch: `fix/rename-without-placeholder-fileset` on origin (JamBalaya56562/duplicati), one commit
[f0f322e4db471ec95ed65705f95d5fdc252b91b2](https://github.com/JamBalaya56562/duplicati/commit/f0f322e4db471ec95ed65705f95d5fdc252b91b2)
on master 922a7c73. Not stacked on the other repair branches.

## Merging with the other repair branches

It changes only `LocalDatabase.RenameRemoteFileAsync` and `LocalDeleteDatabase.DropFilesetsFromTableAsync`,
which none of the other four touch. A temporary merge of all five
(`fix/repair-dlist-keeps-order`, `fix/repair-dlist-reuses-name`, `fix/rename-after-error-avoids-taken-name`,
`fix/dlist-records-fileset-time`, and this one) has only the existing `RepairHandler.cs` conflict between
keeps-order and reuses-name, resolved as in their drafts. Built and tested: all 35 tests in the new and changed test classes of the five branches, plus `Issue6235`, `UnreferencedRowCleanupTests`, `DeleteHandlerTests` and `DisruptionTests.FilesetFilesAsync`, pass.

`RenameAfterErrorTests` (rename branch) and `RepairDlistNameTests` (reuses-name) run an extra repair before
they count versions, because of the placeholder. With this branch that repair is no longer needed. It is
harmless, so it can stay, or be dropped by whichever lands last.

## Title

Do not list a placeholder version after a dlist upload is retried

## Body

When an upload fails, `PutOperation` retries it under a new name. `LocalDatabase.RenameRemoteFileAsync` keeps
the old name registered as `Deleting`, so the file is removed if it shows up later. For a dlist file it
also created a fileset at time 0 for that entry
([32646eb15](https://github.com/duplicati/duplicati/commit/32646eb15969affc0e2871077c5369c8f0f8d78b), #6272,
"so the validation works").

Until the next verification of the destination, that fileset is listed as a backup version. After a repair
whose dlist upload was retried once:

```
v0 03:16:47 full=1 files=2 | v1 03:16:45 full=1 files=1 | v2 1970-01-01 full=0 files=-1
restore --version=2: Restore selection matched zero files, nothing to restore
```

The real versions keep their numbers, because the placeholder is the oldest. A backup clears it when it starts,
so a user sees it after a repair or a purge, not after a backup.

### Why the fileset was there

`LocalDeleteDatabase.DropFilesetsFromTableAsync` checks that the number of dlist volumes it marks for deletion
equals the number of filesets it deleted:

```sql
UPDATE "RemoteVolume" SET "State" = 'Deleting'
WHERE "Type" = 'Files' AND "State" IN ('Uploaded', 'Verified', 'Temporary', 'Deleting')
  AND "ID" NOT IN (SELECT "VolumeID" FROM "Fileset")
-- then: if (deleted != updated) throw "Unexpected number of remote volumes marked as deleted"
```

`Deleting` was added to that list in
[ceae46f39](https://github.com/duplicati/duplicati/commit/ceae46f395b19d90347d44f11ce885ff9cd4a1da) (#6011):
a fileset whose dlist volume is already being deleted has to be deletable, and its volume has to be counted.
But the entry a rename leaves behind is also `Deleting` and has no fileset, so it was counted too. Without the
placeholder fileset, `Issue6235.RepairWithDlistRetriesAsync(1)` fails with
`Unexpected number of remote volumes marked as deleted. Found 1 filesets, but 3 volumes`.

### The change

- `DropFilesetsFromTableAsync` reads the dlist volume IDs of the filesets it deletes, before deleting them.
  The update counts a volume in `Uploaded`, `Verified` or `Temporary` with no fileset, as before. A volume
  that is already `Deleting` now counts only if it belonged to one of the deleted filesets.
- `RenameRemoteFileAsync` no longer creates the fileset. It still registers the old name as `Deleting`, and
  still commits for a dlist.

What the check still stops, and what it now lets through:

| state before the delete | before | after |
|---|---|---|
| the deleted fileset's dlist volume is `Uploaded`/`Verified` | counted | counted |
| the deleted fileset's dlist volume is already `Deleting` (ceae46f39) | counted | counted |
| a dlist volume in `Uploaded`/`Verified`/`Temporary` with no fileset | counted, the delete stops | counted, the delete stops |
| a `Deleting` dlist volume with no fileset (left by a rename) | counted, the delete stops | not counted |

The only change is the last row. That entry is already scheduled for removal. It never had a fileset of its
own, except the placeholder made for this check. It is still returned with the volumes to remove, as before.

### Paths that reach this code

- `DropFilesetsFromTableAsync` is called by `DeleteHandler` (delete, and retention after a backup) and by
  `PurgeFilesHandler` (the original fileset after it is rewritten). Both delete filesets they looked up by
  time. The volumes counted are the same, except for the last row of the table.
- `RenameRemoteFileAsync` is only called from `BackendManager` when it applies a queued rename after a failed
  upload. Any operation that uploads can reach it: backup, synthetic filelists, compact, purge, repair. Only
  dlist entries ever got a placeholder.
- The consistency checks in `LocalDatabase.VerifyConsistencyAsync` do not need it: "filesets with missing
  volumes" looks at filesets, of which there is now one fewer, and "volumes missing filesets" leaves out
  `Deleting` volumes.

**@kenkendk, this changes the safety check you added in 32646eb15 and ceae46f39. Could you confirm that a
`Deleting` dlist volume with no fileset is safe to leave out of the count, or point out a case it was meant
to catch?**

### Tests

New `DeleteFilesetVolumeCountTests` call `DropFilesetsFromTableAsync` on a small database:

| test | master | this branch |
|---|---|---|
| `DroppingAFilesetMarksItsVolumeAsync` (`Verified`, `Uploaded`, `Deleting`) | pass | pass |
| `ADlistVolumeWithoutAFilesetStopsTheDeleteAsync` (`Verified`, `Uploaded`, `Temporary`) — the delete still stops | pass | pass |
| `AnEntryLeftByARenameDoesNotCountAsync` | **fail**: `Found 1 filesets, but 2 volumes` | pass |

New `RenamePlaceholderFilesetTests` make the first dlist upload fail once (`DeterministicErrorBackend`), then
list the versions:

| test | master | this branch |
|---|---|---|
| `RepairRetryLeavesNoExtraVersionAsync` | **fail**: `v2 1970-01-01 full=0 files=-1` listed | pass |
| `PurgeRetryLeavesNoExtraVersionAsync` | **fail**: `v2 1970-01-01 full=0 files=-1` listed | pass |

Also passing (32 in total with the above): `Issue6235.RepairWithDlistRetriesAsync` (1 and 2),
`UnreferencedRowCleanupTests`, `DeleteHandlerTests`, `LockingDeleteAndCompactTests`, `PurgeTesting`,
`RepairFilesetTimestampTests`, `DisruptionTests.FilesetFilesAsync`, `KeepTimeRetentionAsync`,
`RetentionPolicyRetentionAsync`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
