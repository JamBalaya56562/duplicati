## What happens

`LocalDatabase.GetFilesetIDsAsync` has two modes. For a restore time it selects the filesets at or
before that time, and when none qualifies it falls back to every fileset, newest first, with the
`RestoreTimeNoMatch` warning - the documented behaviour of `--time` for a restore. With
`singleTimeMatch` it selects the fileset whose timestamp equals the time
([LocalDatabase.cs:1510-1548](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Database/Local/LocalDatabase.cs#L1510-L1548)).
The fallback runs in both modes, so an exact time that matches nothing yields every fileset.

Both exact-match callers check for an empty result, and neither check can ever fire:

| Caller | Expects on no match | Gets |
|---|---|---|
| `ListFolderHandler` ([:54-61](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/ListFolderHandler.cs#L54-L61)), behind `POST /api/v2/backup/list-folder` | `NoFilesetsFound` | with one fileset in the database: that version's listing, presented as the requested one; with more: `MultipleFilesetsFound`, "please specify a single version or time" - for a time that matched none |
| `SetLocksHandler.ResolveFilesetIdsAsync` ([:141-152](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/SetLocksHandler.cs#L141-L152)), the post-backup object lock | skip the version (`if (matched.Length > 0)`) | with one fileset: the newest version's volumes are locked for a version time that does not exist |

The web UI sends back the times it got from `list-filesets`, so it does not hit this; a client of the
V2 API with any other time does. The backup passes the times of the filesets it just wrote to the lock
handler, so that caller is not hit in practice either - but the guard it carries says what it expects.

## The change

When an exact match was requested and nothing matched, the lookup returns nothing. The at-or-before
mode keeps its fallback and warning, and a database without any fileset still raises
`NoBackupAtDate` in both modes (that is the error the partial database of a restore-from-files shows
while it is empty; #6597).

## Red to green

| Test | Before |
|---|---|
| `DirectListHandlerTests.GetFilesetIDs_ExactMatchWithoutAMatch_ReturnsNothingAsync` (database with filesets at 1000 s and 2000 s) | fails: exact match at 1500 s `Expected: <empty> But was: < 2, 1 >`; the at-or-before cases in the same test pass before and after |
| `DirectListHandlerTests.ListFolder_TimeThatMatchesNoFileset_IsAnErrorAsync` (two backups, `--time` a day before the first) | fails: `Expected: "NoFilesetsFound" But was: "MultipleFilesetsFound"`; the exact time of a version lists it before and after |
| `SetLocksHandlerTests.DoesNotLockAnythingForAVersionThatMatchesNoFilesetAsync` (one backup, a version time a day before it) | fails: no exception, the fileset's volumes are locked |

Red then green on Windows and on Linux (WSL). `DirectListHandlerTests`, `SetLocksHandlerTests` and
`TestCategory=RestoreHandler` (the at-or-before path) are green.

## Observation, not changed here

`SetLocksHandler` reports "No version specified" (`NoVersionForLockOperation`) when versions were
specified but none matched; with this change that message can now be reached from the supplied-versions
path. A wording of its own would be clearer.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
