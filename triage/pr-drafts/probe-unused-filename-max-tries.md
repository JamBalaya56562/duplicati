# PR draft: fix/probe-unused-filename-max-tries

Branch: `fix/probe-unused-filename-max-tries` on origin (JamBalaya56562/duplicati), one commit
[78359afc39fc1156b1d468f07f66cf39f135f161](https://github.com/JamBalaya56562/duplicati/commit/78359afc39fc1156b1d468f07f66cf39f135f161)
on master 922a7c73. Not stacked.

Upstream issues searched: "FailedToFindUnusedFilename", "Failed to find an unused filename". No match.

Merging: touches `FilesetVolumeWriter.cs`, which `fix/dlist-records-fileset-time` and
`fix/rename-after-error-avoids-taken-name` also change, in other places. A temporary merge with both and
`fix/synthetic-filelist-after-interrupted-time` has no conflict, and `ProbeUnusedFilenameTests` passes there.
The rename branch's `MaxRenameTries = 60` ("the same limit as ProbeUnusedFilenameNameAsync") then matches a limit
that is actually enforced.

## Title

Stop probing for a dlist name after the given number of tries

## Body

`ProbeUnusedFilenameNameAsync` looks for the first free dlist name from a start time, one second at a time, and is
documented to give up after `maxTries` (60) names with `FailedToFindUnusedFilename`. The counter was never
incremented (it lost its `++s` in
[be16323f2](https://github.com/duplicati/duplicati/commit/be16323f24129f035900fd8326ebca989473d216)), so the limit
never applied and the error could not be raised: with every name taken it went on to the next second.

It now tries at most `maxTries` names. Nothing changes as long as one of the first 60 names is free.

Callers: synthetic filelists, purge, and the two repair paths that write a dlist file. With 60 consecutive taken
names (dlist files one second apart for a minute) they now fail with `FailedToFindUnusedFilename` instead of
picking a name more than a minute after the fileset.

### Tests

New `ProbeUnusedFilenameTests`, against a local database with dlist names registered from the start time:

| test | master | this branch |
|---|---|---|
| `ReturnsTheFirstFreeNameWithinTheTriesAsync(0)` | pass | pass |
| `ReturnsTheFirstFreeNameWithinTheTriesAsync(59)` | pass | pass |
| `FailsWhenEveryNameWithinTheTriesIsTaken` (60 taken) | **fail**: no exception | pass |

Also passing: `RepairFilesetTimestampTests`, `RepairHandlerTests.RepairMissingDlistVolumeAsync`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
