# PR draft: fix/repair-missing-filesets-upload-in-turn

Branch: `fix/repair-missing-filesets-upload-in-turn` on origin (JamBalaya56562/duplicati), one commit
[8d084333b7db6624a8dfbd7a4aa65a42eb4299e8](https://github.com/JamBalaya56562/duplicati/commit/8d084333b7db6624a8dfbd7a4aa65a42eb4299e8)
**stacked on `fix/rename-after-error-avoids-taken-name`**
([99c681f5a1fd66d3af0c3c5a75609db64d0de94e](https://github.com/JamBalaya56562/duplicati/commit/99c681f5a1fd66d3af0c3c5a75609db64d0de94e), on master 922a7c73).

Merge order: open this only after `fix/rename-after-error-avoids-taken-name` is merged, then rebase onto master
(no stacked PRs). Without the base, the retry name is not checked at all, so the test fails for the base's
reason as well.

Possible conflict: a session is adding synthetic-dlist tests to `RenameAfterErrorTests.cs` on the same base.
This commit changes the helper `RunWithOneFailedUploadAsync` (new optional `failures` parameter, a set of
failed names instead of a flag). Existing callers are unchanged.

## Title

Upload replacement dlists one at a time in repair

## Body

A follow-up to #<rename-after-error-avoids-taken-name>. That change makes the retry of a failed dlist upload skip
names that are taken in the database. The check reads the database only, and one repair path writes the
renames of retries to the database too late for it.

When filesets have no registered dlist volume, `RepairHandler` uploads a dlist for each of them in a loop
with `PutAsync(..., waitForComplete: false, onDbUpdate: null)`. The uploads run without waiting, and the
renames of retried uploads stay in the backend manager's queue until a later flush. A second retry, or the
name probe for the next fileset, does not see the first rename.

### How to reproduce

Two versions one second apart, both dlist volumes missing from the database and from the destination, and
the first upload of both replacements failing (`DeterministicErrorBackend`). The replacements are named at
`t` and `t+1`. The older retry skips `t+1`, which is taken, and goes to `t+2`. The newer retry goes to `t+2`
as well, because the older rename is not in the database yet.

On the base branch:

```
error: SqliteException: SQLite Error 19: 'UNIQUE constraint failed: Remotevolume.Name'
dlist after:  duplicati-20261023T092233Z.dlist.zip        <- one dlist for two versions
volume 9  ...092233Z Uploading
volume 10 ...092232Z Uploading
volume 12 ...092231Z Deleting
fileset 3 00:00:00 volume 12
remote contents: a.txt b.txt c.txt                       <- the older version was overwritten
versions after:  v0 only
recreate: No filelists found on the remote destination
```

### The change

The loop uploads with `waitForComplete: true` and flushes the backend messages in `onDbUpdate`, like the purge
does. Each rename after a failed upload is in the database before the upload under the new name, so the next
retry and the next name probe see it. It also means the backend manager no longer reads the database from its
own thread while the repair keeps writing to it.

The cost is that these dlists are uploaded one after another. This path only runs when the database has
filesets without a dlist volume, which is rare, and a dlist is small.

Other dlist uploads were checked and need no change:

- Backup (`UploadRealFilelist`) and synthetic filelists flush in `onDbUpdate`. A synthetic filelist is uploaded
  with `waitForComplete: true` before the real one.
- Purge uploads with `waitForComplete: true` and flushes in `onDbUpdate`.
- Repair of a missing dlist file (`RunRepairDlistAsync`) waits for the backend queue after each upload.

### Testing

| test | base branch | this branch |
|---|---|---|
| `RenameAfterErrorTests.RepairRetriesOfTwoDlistsDoNotTakeTheSameNameAsync` (new) | **fail**: `UNIQUE constraint failed: Remotevolume.Name`, one dlist left, a recreate finds no versions | pass |

Also passing: the rest of `RenameAfterErrorTests`, `RepairHandlerTests.RepairMissingDlistVolumeAsync`,
`RepairFilesetTimestampTests` (9 of 9). No new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
