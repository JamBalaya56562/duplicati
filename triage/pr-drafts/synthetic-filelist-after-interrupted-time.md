# PR draft: fix/synthetic-filelist-after-interrupted-time

Branch: `fix/synthetic-filelist-after-interrupted-time` on origin (JamBalaya56562/duplicati), one commit
[515b01961f832f7b1dc94a789ee72df35b9861f2](https://github.com/JamBalaya56562/duplicati/commit/515b01961f832f7b1dc94a789ee72df35b9861f2)
on master 922a7c73 (upstream master has since moved to 2bd33256, proprietary/ license files only). Not stacked.

Upstream issues searched: "synthetic filelist empty", "interrupted backup empty version", "Uploading filelist from
previous interrupted backup", "partial backup no files". No match.

## Relation to fix/synthetic-filelist-keeps-interrupted-files (2026-10-24)

Branch now (on master 5ef1a237): the fix
[66bede341cf7edcb88484792f1f044e900671bf5](https://github.com/JamBalaya56562/duplicati/commit/66bede341cf7edcb88484792f1f044e900671bf5) and a comment-only commit
[4705397c9a5830db0559241eb15e5cb141503408](https://github.com/JamBalaya56562/duplicati/commit/4705397c9a5830db0559241eb15e5cb141503408).
Tests (SyntheticFilelist* + DisruptionTests TestMultiExceptionOnDlist/TestUploadException*/StopNow/StopAfterCurrentFile/
TestDlistUploadWithOperationCancellation): this branch alone 26/26, merged with the other synthetic branch 28/28,
0 warnings.

- That branch fills the synthetic fileset from the interrupted fileset by ID, so it no longer depends on the time
  lookup, and it also fixes the empty version this branch fixes (this branch's test passes there alone).
- User's decision (a): both land. Second commit on this branch rewords the comment to a reason true with or without
  that branch: the synthetic and the interrupted fileset never have the same time. **Either can merge first**, no
  textual conflict. If that branch merges first, the PR body's "the previous fileset is found by time" paragraph
  describes the code before it; say so in a sentence (the name change still keeps the two filesets apart in time).
- The `fix/rename-after-error-avoids-taken-name` test change below is needed whenever **this** branch and the rename
  branch are both in, regardless of the other synthetic branch.

## Merging with the other dlist branches (checked on a temporary merge)

A merge of this, `fix/probe-unused-filename-max-tries`, `fix/rename-after-error-avoids-taken-name` and
`fix/dlist-records-fileset-time` has **no textual conflict** and builds. But one test of the rename branch depends on
the old start time:

- `RenameAfterErrorTests.SyntheticFilelistRetryDoesNotTakeTheNameOfTheInterruptedDlistAsync` builds its clash with
  an interrupted backup whose dlist upload is retried once (`number-of-retries = 1`). With this fix the synthetic dlist
  is named T+2 instead of T, the retry is T+3, and the test fails at its precondition (`Expected ...164519Z`, `But was
  ...164521Z`). With `number-of-retries = 2` (dlist renamed T -> T+1 -> T+2, so this fix names the synthetic T+1 and
  the retry is T+2) the precondition holds again: in the merged tree it passes, and fails with the rename check
  removed (`RemoteListVerificationException`, same as on master).
- So **whichever of the two branches merges second changes that test to `"2"`, `Has.Count.EqualTo(3)` and
  `interruptedPuts[2]`**. On its own, the rename branch has to keep `1` (with `2`, master names the synthetic T and the
  retry T+1 is free).

All other tests in the merged tree pass: `SyntheticFilelistContentTests` (2), `ProbeUnusedFilenameTests` (3),
`DlistFilesetTimeTests` (3), the other 3 `RenameAfterErrorTests`.

## Title

Give a synthetic dlist a time after the interrupted backup

## Body

When a backup is interrupted before its dlist file is uploaded, the next backup uploads a synthetic dlist for it.
That version is supposed to hold the files of the interrupted backup. In one case it holds none.

The synthetic fileset takes its files from the previous fileset. With no complete backup before the interrupted one,
the previous fileset is found by time: the newest one with a time **before** the synthetic fileset's time
(`GetPreviousFilesetIDAsync`, `"Timestamp" < @Timestamp`). That is the interrupted fileset only if the synthetic
fileset is later.

Until [be16323f2](https://github.com/duplicati/duplicati/commit/be16323f24129f035900fd8326ebca989473d216) the
synthetic dlist name was probed from one second after the interrupted fileset. Since then it is probed from the
interrupted fileset's time itself. That name is normally taken by the interrupted backup's own dlist, so the result
is still one second later. But when that dlist upload failed and was retried under the next second, the name of the
fileset time is free (the placeholder the rename leaves is removed by the next verification). The synthetic fileset
then gets the same time as the interrupted one, the interrupted one is not "before" it, and the synthetic version is
empty.

### How to reproduce

The first backup's dlist upload fails twice with `--number-of-retries=1`, then a normal backup:

```
versions: v0 16:34:47Z full=1 files=1 | v1 16:34:43Z full=0 files=-1
list --version=1: (nothing)
```

After a database recreate the version is still empty, since the uploaded dlist file lists no files. For a user, the
version of the interrupted backup is listed but restores nothing. The backup after it is complete, so nothing else
is lost.

### The change

Probe the synthetic dlist name from one second after the interrupted fileset, as before be16323f2.

### Tests

New `SyntheticFilelistContentTests.SyntheticFilelistHasTheFilesOfTheInterruptedBackupAsync`: an interrupted backup
(dlist upload fails, with 0 or 1 retries), a normal backup, then the files of the synthetic version, before and
after a recreate.

| test | master | this branch |
|---|---|---|
| `(0)` | pass | pass |
| `(1)` | **fail**: version 1 lists nothing | pass |

Also passing: `SyntheticFilelistMetadataTests` (4), `DisruptionTests.TestMultiExceptionOnDlistAsync` (8).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
