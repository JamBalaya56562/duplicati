When a backup is interrupted before its dlist file is uploaded, the next backup uploads a synthetic dlist for it. If there was a complete backup before the interrupted one, the files that the interrupted backup added were left out of that version.

The synthetic fileset took its files only from the last complete fileset (`prevId`).

- Files that were **changed** in the interrupted backup still showed their new version, because the newest `FileLookup` row for the path is used.
- Files that were **new** in the interrupted backup were not in the previous fileset, so they were not in the synthetic version either, even though their data had been uploaded.

The intent, as described in #2506 and #3982, is that the synthetic dlist is the previous backup plus whatever the interrupted backup managed to back up. Without a complete backup before, the code already did that (it found the interrupted fileset by time). With one, it has copied only the complete fileset since [a75f8e087](https://github.com/duplicati/duplicati/commit/a75f8e087dcf733f0bd09948ee58b65404db04d2) (2013).

## How to reproduce

Back up `a.txt`, add `b.txt`, run a backup whose dlist upload fails, then run a normal backup:

```
versions: v0 full=1 [a.txt] | v1 full=0 [a.txt] | v2 full=1 [a.txt]
```

`b.txt` is not in the synthetic version (v1). If `b.txt` is deleted before the next backup, it is in no version at all, although its data was uploaded by the interrupted backup.

## The change

The synthetic fileset is filled from the interrupted fileset first. Then the files of the previous complete fileset that the interrupted backup did not get to are added; paths already present are skipped, as before. Deleted files are still only dropped by a backup that completes.

## Testing

New `SyntheticFilelistNewFilesTests.SyntheticFilelistHasTheFilesAddedByTheInterruptedBackupAsync(keepNewFile)`. It checks the files of the synthetic version, a restore of `b.txt` from it, and the files after a database recreate.

| test | master | this branch |
|---|---|---|
| `(True)` | **fail**: v1 is `[a.txt]` | pass |
| `(False)` | **fail**: v1 is `[a.txt]` | pass |

Run again after rebasing onto master [c16a28aa8](https://github.com/duplicati/duplicati/commit/c16a28aa8cfb8564fa23b9caa5499b33711aae80), in one build with the other branches I am opening today: 48 tests passed, among them all `SyntheticFilelist*` tests. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
