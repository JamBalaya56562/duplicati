# PR draft: fix/repair-dlist-reuses-name

Branch: `fix/repair-dlist-reuses-name` on origin (JamBalaya56562/duplicati), one commit
[fa8934ad275f374cca5e96a0c9e324f0f22a14d6](https://github.com/JamBalaya56562/duplicati/commit/fa8934ad275f374cca5e96a0c9e324f0f22a14d6)
on master 7cdde1585522. Not stacked on `fix/repair-dlist-keeps-order`.

## Merge order and conflict

Both branches change the same loop in `RepairHandler.cs`. Merge **`fix/repair-dlist-keeps-order` first**,
then rebase this one. The rebase conflicts in one hunk. Resolve it by keeping keeps-order's lines that
build and sort the list (the outer loop gets `timestamp` from the database), and this branch's same-name
block, with the name time in its own variable:

```csharp
var nameTime = VolumeBase.ParseFilename(n.Name).Time;
if (string.Equals(VolumeBase.GenerateFilename(RemoteVolumeType.Files, m_options, null, nameTime), n.Name, StringComparison.Ordinal))
{
    var sameNameWriter = newEntry = new FilesetVolumeWriter(m_options, nameTime);
    await RunRepairDlistInPlaceAsync(backendManager, db, sameNameWriter, n, cancellationToken).ConfigureAwait(false);
    continue;
}
// ... ProbeUnusedFilenameNameAsync(db, m_options, timestamp, ...) as on keeps-order
```

Checked with a temporary merge resolved that way and built locally: all 11 tests in `RepairDlistNameTests`, `RepairDlistOrderTests` and `RepairFilesetTimestampTests`, plus `DisruptionTests.FilesetFilesAsync`, pass.
No upstream issue found (same searches as keeps-order).

## Title

Upload a missing dlist file again under its own name

## Body

When a dlist file is missing from the destination, repair writes it again and gives the
replacement the first free name at or after the fileset time. The missing file's own name is
still registered in the database, so the new name was always at least one second later. With
two filesets one second apart, losing only the older dlist put its replacement **after** the
newer one's file:

```
duplicati-20261022T111011Z.dlist.zip, duplicati-20261022T111010Z.dlist.zip   (oldest fileset first)
```

The file is gone from the destination, so its name is free there. When the current options
produce exactly that name, repair now writes the dlist again from the fileset in the database and
uploads it under that name. It keeps the existing remote volume row and fileset, so neither the
name nor the fileset time moves. If the compression or encryption module has changed, the name
differs, and the old path is used (the name at the original time with the new extensions is free
anyway).

**This writes to a name the destination has held before.** Elsewhere Duplicati avoids that: a
failed upload is retried under a new name (`RenameFileAfterError`). If a destination refuses the
write, or the upload fails for any other reason, that same rename gives the file a name one second
later, which is what repair did before this change. A destination whose listing lags and still
holds the old file gets it overwritten with a file that describes the same fileset.

### Tests

New `RepairDlistNameTests`:

| test | before | after |
|---|---|---|
| `RepairOfTheOlderDlistFileKeepsTheOrderAsync`: filesets one second apart, only the older dlist deleted | **fail**: `...T111011Z, ...T111010Z` | pass |
| `RepairUploadsMissingDlistFilesUnderTheirOwnNamesAsync`: same names after the repair, `test` clean, recreate gives the same versions | **fail**: names `...23Z, ...26Z` became `...24Z, ...27Z` | pass |
| `RepairRenamesTheDlistFileWhenItsUploadFailsAsync`: the first upload under the original name fails (`DeterministicErrorBackend`); the file ends up one second later, and the versions are unchanged | **fail**: "The upload under the original name was not attempted" | pass |

`RepairFilesetTimestampTests.RepairKeepsTheFilesetTimeWhenAllDlistFilesAreMissingAsync` asserted
that the names change. It now asserts that they stay the same. The other `RepairFilesetTimestampTests`,
`RepairHandlerTests.RepairMissingDlistVolumeAsync` (both cases), `RepairMissingFilesetVolumeAsync`
and `DisruptionTests.FilesetFilesAsync` pass.

The upload-failure test runs a second repair before comparing versions. Renaming a dlist after a
failed upload leaves a placeholder fileset (time 0) for the failed name
(`LocalDatabase.RenameRemoteFileAsync`). The next verification removes it. That behaviour already
existed and is not changed here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
