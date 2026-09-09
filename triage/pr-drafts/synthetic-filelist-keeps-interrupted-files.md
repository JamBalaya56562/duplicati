# PR draft: fix/synthetic-filelist-keeps-interrupted-files

Branch: `fix/synthetic-filelist-keeps-interrupted-files` on origin (JamBalaya56562/duplicati), one commit
[e40c7009c0d121245944fbce69145831bb26e54b](https://github.com/JamBalaya56562/duplicati/commit/e40c7009c0d121245944fbce69145831bb26e54b)
on master 5ef1a237. Not stacked.

Upstream issues searched: "interrupted backup new files missing", "synthetic filelist missing files", "interrupted
backup files not in version", "partial backup new files not restored", open issues with "interrupted backup" /
"synthetic". No match.

## Overlap with fix/synthetic-filelist-after-interrupted-time (checked on a temporary merge)

- No textual conflict (both edit UploadSyntheticFilelist.cs, different lines).
- This change no longer finds the files of the interrupted backup by time, so it **also fixes the empty synthetic
  version that branch fixes**: that branch's `SyntheticFilelistContentTests` (0) and (1) pass on this branch alone
  (copied in for the run, not committed).
- User's decision (a): both land. That branch got a second commit that rewords its comment to a reason true with or
  without this branch (the two filesets never share a time). **Either can merge first**, no rebase change needed.
- `fix/rename-after-error-avoids-taken-name`: this branch does not change the synthetic dlist's name, so that
  branch's `SyntheticFilelistRetryDoesNotTakeTheNameOfTheInterruptedDlistAsync` needs its `"1"` → `"2"` change only
  because of `fix/synthetic-filelist-after-interrupted-time` (see that draft), not because of this one. Checked: this
  branch merged with the rename branch (a29ac179, unchanged test with `"1"`) builds with 0 warnings and
  `RenameAfterErrorTests` (4) + `SyntheticFilelist*` (6) pass 10/10.
- Tests with the other synthetic branch's comment commit (4705397c) in a temporary merge: 28/28 (same set as below
  plus its `SyntheticFilelistContentTests`), 0 warnings.
- In the merged tree: builds with 0 warnings, `SyntheticFilelist*` 8/8 pass (NewFiles 2, Content 2, Metadata 4).

## Title

Keep the files of the interrupted backup in a synthetic dlist

## Body

When a backup is interrupted before its dlist file is uploaded, the next backup uploads a synthetic dlist for it.
Files that the interrupted backup added were left out of that version when there was a complete backup before it.

The synthetic fileset took its files only from the last complete fileset (`prevId`). Files that were changed in the
interrupted backup still showed their new version (the newest `FileLookup` row for the path is used), but files that
were new in the interrupted backup were not in the previous fileset, so they were not in the synthetic version
either, even though their data had been uploaded.

The intent, as described in [#2506](https://github.com/duplicati/duplicati/issues/2506) and
[#3982](https://github.com/duplicati/duplicati/issues/3982), is that the synthetic dlist is the previous backup plus
whatever the interrupted backup managed to back up. Without a complete backup before, the code already did that (it
found the interrupted fileset by time); with one, it has copied only the complete fileset since
[a75f8e087](https://github.com/duplicati/duplicati/commit/a75f8e087dcf733f0bd09948ee58b65404db04d2) (2013).

### How to reproduce

Back up `a.txt`, add `b.txt`, run a backup whose dlist upload fails, then a normal backup:

```
versions: v0 full=1 [a.txt] | v1 full=0 [a.txt] | v2 full=1 [a.txt]
```

`b.txt` is not in the synthetic version (v1). If `b.txt` is deleted before the next backup, it is in no version at all,
although its data was uploaded by the interrupted backup.

### The change

Fill the synthetic fileset from the interrupted fileset first, then add the files of the previous complete fileset that
the interrupted backup did not get to (paths already present are skipped, as before). Deleted files are still only
dropped by a backup that completes.

### Tests

New `SyntheticFilelistNewFilesTests.SyntheticFilelistHasTheFilesAddedByTheInterruptedBackupAsync(keepNewFile)`: the
files of the synthetic version, a restore of `b.txt` from it, and the files after a database recreate.

| test | master | this branch |
|---|---|---|
| `(True)` | **fail**: v1 is `[a.txt]` | pass |
| `(False)` | **fail**: v1 is `[a.txt]` | pass |

Also passing (28 in one run): `SyntheticFilelistMetadataTests` (4), `DisruptionTests.TestMultiExceptionOnDlistAsync` (8),
`TestUploadExceptionWithNoRetriesAsync`, `TestUploadExceptionOnFirstDlistAsync` (4),
`TestUploadExceptionOnFirstDlistWithRepairAsync` (4), `StopNowAsync`, `StopAfterCurrentFileAsync`,
`TestDlistUploadWithOperationCancellationAsync`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
