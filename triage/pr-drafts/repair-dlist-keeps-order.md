# PR draft: fix/repair-dlist-keeps-order

Branch: `fix/repair-dlist-keeps-order` on origin (JamBalaya56562/duplicati), one commit [caa640cecdf01201f2d9c19045695bb6a0acb619](https://github.com/JamBalaya56562/duplicati/commit/caa640cecdf01201f2d9c19045695bb6a0acb619) on master 7cdde1585522.
No upstream issue found (searched "repair dlist", "repair dlist order", "repair version swapped",
"repair fileset timestamp", "dlist renamed repair", "version order after repair").

## Title

Keep version order when repair replaces missing dlist files

## Body

Repairing a dlist file that is missing from the destination gives the replacement the first
free name at or after the fileset time. Two things in that loop go wrong when two filesets are
close together:

1. **The missing files are replaced in whatever order the database lists them.** If the newer
   one goes first it takes the name the older one would have used, and the older one is pushed
   past it. With filesets at :52 (full) and :53 (partial), the partial got :54 and the full :55.
   That is exactly the `DisruptionTests.FilesetFilesAsync` failure seen on ubuntu CI:

   ```
   after the repair the older dlist file is not the full backup: dlist files: 2026-10-22 08:30:55Z full,
   2026-10-22 08:30:54Z partial; database versions: #0 at 2026-10-22 08:30:53Z partial, #1 at 2026-10-22 08:30:52Z full
   ```

   The probe only skips names that are already taken, and names only become taken, so replacing
   the oldest first can never push an older name past a newer one.

2. **The fileset time was taken from the missing file's name.** After one repair that name is
   later than the fileset (:55 for a fileset at :52), so losing the dlist files a second time and
   repairing again moved the filesets to the name times. With the names reversed by (1), that
   swaps the backups between versions: `--version=0` then restores the older backup. The time
   now comes from the fileset in the database, which is what the original fix in
   [8bc41a7098dcb2d7f8d4e79b183fa80c9bbfa808](https://github.com/duplicati/duplicati/commit/8bc41a7098dcb2d7f8d4e79b183fa80c9bbfa808) meant to keep.

A recreate was not affected: the replaced dlist records its fileset time and the recreate uses it.

### Tests

`RepairDlistOrderTests` moves the older of two filesets to one second before the newer and, for
the "newer first" case, gives its volume a higher ID so the database lists it last.

| test | before | after |
|---|---|---|
| `RepairOfAllDlistFilesKeepsTheirOrderAsync(False)` | pass | pass |
| `RepairOfAllDlistFilesKeepsTheirOrderAsync(True)` | **fail**: `...T100757Z, ...T100756Z` (oldest fileset first) | pass |
| `SecondRepairKeepsTheVersionsAsync` | **fail**: "Repair 2 swapped the backups between the versions" | pass |
| `RecreateAfterRepairKeepsTheVersionsAsync` | pass | pass |

`RepairFilesetTimestampTests` (the existing tests for the fileset time) still pass.

### Not covered

When only the older of two filesets one second apart loses its dlist, the replacement still
has to take a name after the newer one, because the only free name in between is its own old
name, which stays registered until later in the repair. The versions are no longer affected by
that (point 2), but the file names are out of order. Fixing it means reusing the old name and is
left for a separate change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
