# PR draft: fix/dlist-records-fileset-time

Branch: `fix/dlist-records-fileset-time` on origin (JamBalaya56562/duplicati), one commit
[79dfdede6df8484dbf7870519616fdb8167fde82](https://github.com/JamBalaya56562/duplicati/commit/79dfdede6df8484dbf7870519616fdb8167fde82)
on master 7cdde1585522. Not stacked on the other repair branches.

## Which writers it covers

The `CreateFilesetFile` callers on master:

| caller | records the time before | fileset time |
|---|---|---|
| `BackupHandler` (the backup's own dlist) | no | name time when created |
| `UploadSyntheticFilelist` | no | name time when created (`fileTime`) |
| `PurgeFilesHandler` | no | name time when created (`ts`) |
| `RepairHandler`, missing remote registration | yes | original fileset time |
| `RepairHandler.RunRepairDlistAsync` | yes | original fileset time |

The first three have the same shape: the fileset gets the time of the name the file is created with.
Only a retried upload moves the name. So they are handled together, with one change in
`CreateFilesetFile`: when no time is given, it records the time of the file's own name. The callers are
unchanged. Compact does not write dlist files. RecoveryTool recompress copies the file's contents, and
`RecompressAndRecreateDatabaseAsync` still passes.

## Merging with the other repair branches

Merges cleanly with `fix/repair-dlist-keeps-order`, `fix/repair-dlist-reuses-name` and
`fix/rename-after-error-avoids-taken-name`. It touches `FilesetVolumeWriter.cs`, which the rename branch
also changes, in a different place. The only conflict in a merge of all four is the existing
`RepairHandler.cs` one between keeps-order and reuses-name (four-sided once all are in), resolved as in the reuses-name and
rename drafts. A temporary merge of all four built cleanly, and all 16 tests in `DlistFilesetTimeTests`, `RenameAfterErrorTests`, `RepairDlistOrderTests`, `RepairDlistNameTests`, `RepairFilesetTimestampTests` and `DisruptionTests.FilesetFilesAsync` pass.

After this and the rename branch are both merged, `RenameAfterErrorTests` could compare exact version
times after a recreate instead of only the versions (its comment says why it does not). That is a
follow-up for whichever of the two lands second.

## Title

Record the fileset time in every dlist file

## Body

A database recreate takes a fileset's time from the name of its dlist file, unless the file records the
time (added for repaired dlist files in
[0a6a23725](https://github.com/duplicati/duplicati/commit/0a6a23725)). Only the repair paths recorded it,
because they are the ones that give a file a name other than its fileset's time.

A failed upload is retried under a name one second later. So when the dlist upload of a backup, a
synthetic filelist or a purge is retried, a later recreate reads the version back one second late:

```
backup: before v0 22:43:44, recreate v0 22:43:45
purge:  before v1 22:43:53, recreate v1 22:43:54
```

For a user, `--time` and the version list then show a time the backup was never made at. With versions
close together, the shift can also reach a neighbour's time.

`CreateFilesetFile` now records the time of the file's own name when the caller does not give one. That is
the fileset time for every caller that leaves it out. The file then keeps that time whatever name a retry
gives it. Callers that pass a time are unchanged.

Older versions ignore the extra field, as they already do for repaired dlist files.

### Tests

New `DlistFilesetTimeTests`: a backup, and a purge, whose dlist upload fails once
(`DeterministicErrorBackend`), followed by a recreate.

| test | before | after |
|---|---|---|
| `BackupRetryKeepsTheFilesetTimeAcrossARecreateAsync` | **fail**: v0 22:43:44 → 22:43:45 | pass |
| `PurgeRetryKeepsTheFilesetTimeAcrossARecreateAsync` | **fail**: v1 22:43:53 → 22:43:54 | pass |

Also passing: `RepairFilesetTimestampTests`, `PurgeTesting`, `RecoveryToolTests.RecompressAndRecreateDatabaseAsync`,
`RepairHandlerTests.RepairMissingDlistVolumeAsync`, `DisruptionTests.FilesetFilesAsync`.

Synthetic filelists go through the same writer call but have no test of their own.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

## Update 2026-10-23: synthetic filelist test added

The branch is now two commits on master 922a7c73:
[ec5c51e0397dfdc19608d50c4a2ce5c51dee6247](https://github.com/JamBalaya56562/duplicati/commit/ec5c51e0397dfdc19608d50c4a2ce5c51dee6247) (the fix) and
[23ca32524761a4ae35c3a3c810a4bbae53ff0ddf](https://github.com/JamBalaya56562/duplicati/commit/23ca32524761a4ae35c3a3c810a4bbae53ff0ddf) (the test).

New test `DlistFilesetTimeTests.SyntheticFilelistRetryKeepsTheFilesetTimeAcrossARecreateAsync`: a backup whose
dlist upload fails with no retries (as in `DisruptionTests.TestMultiExceptionOnDlistAsync`), then a backup that
uploads the synthetic dlist for it, with that upload failing once (the test checks that the failed name is earlier
than the second backup, so it is the synthetic one), then a recreate.

| | result |
|---|---|
| master `FilesetVolumeWriter.cs` | **fail**: `before: v1 18:30:00 full=0`, `recreate: v1 18:30:01 full=0` (dlist files ...093001Z, ...093006Z) |
| this branch | pass (all 3 `DlistFilesetTimeTests`) |

For the PR body table, add the row:
`SyntheticFilelistRetryKeepsTheFilesetTimeAcrossARecreateAsync` | **fail**: v1 18:30:00 → 18:30:01 | pass
and drop the sentence "Synthetic filelists go through the same writer call but have no test of their own."
