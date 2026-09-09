Fixes #7005
Fixes #6866

## What happens

A Windows snapshot that fails after its snapshot set was started leaves the set in progress. That happens, for example, when one source is on a volume that cannot be snapshotted: `SnapshotManager.InitShadowVolumes` calls `StartSnapshotSet`, then `CheckAndAddSupportedVolumes` throws "Drive not supported for snapshot". Every later snapshot then fails with `VSS_E_SNAPSHOT_SET_IN_PROGRESS` (0x80042316) until the process ends. For the server, that is every backup until it is restarted. With the Vanara provider it showed as a `NullReferenceException` in `CVssBackupComponents.StartSnapshotSet` instead.

It is not limited to the process: in the runs below, a set left in progress by one process still made the first snapshot of the next process fail a few minutes later, as #7005 says of other VSS applications.

Two causes:

- Since [`2920705699fc7f78ccb6170385f31064891e0f8f`](https://github.com/duplicati/duplicati/commit/2920705699fc7f78ccb6170385f31064891e0f8f) (#7329), `CreateSnapshotManagerCore` creates the `SnapshotManager` in a local variable. When the setup throws, its caller never gets the manager, so its `manager?.Dispose()` does nothing, and the manager and its provider are never disposed.
- The Vanara provider never aborts a set that was started but not created, so disposing it does not end the set either.

## The change

- `CreateSnapshotManagerCore` disposes the manager when its setup throws. The caller no longer needs its own dispose, and its retry with the Microsoft provider now starts with no set in progress.
- `VanaraVssBackup` calls `AbortBackup` on dispose when the set was started but `DoSnapshotSet` did not complete, and releases the backup components.

The Native and AlphaVSS providers are not changed: with the manager disposed, they ended the set without `AbortBackup` in the runs below.

## Checked

VSS needs an elevated process, so all of this was run from an elevated shell on Windows 11, each run in its own process.

`WindowsSnapshotFailureTests.ASnapshotAfterAFailedSnapshotWorks` (new) takes a snapshot of a folder, then one with an extra source on a drive letter that is not in use, which fails after the set is started, then one of the folder again. It is ignored when the process is not elevated, or when no snapshot can be made at all.

| Provider | Before | After |
|---|---|---|
| Native (default) | **fails**: the third snapshot throws `COMException (0x80042316)` | passes |
| Vanara | **fails**: the third snapshot throws `NullReferenceException` | passes |

How much of the change each provider needs, with a probe that makes the first snapshot fail with a source on `\\localhost\C$` and then takes a second one:

| Second snapshot | Native | Vanara | AlphaVSS |
|---|---|---|---|
| master | fails, 0x80042316 | fails, `NullReferenceException` | (the first already failed, "already in progress", left by the run before) |
| manager disposed on failure | works | fails, `NullReferenceException` | works |
| + Vanara releases the components | | fails, `NullReferenceException` (2 of 2) | |
| + Vanara aborts the set | | works (2 of 2) | |
| + both (this PR) | works | works | works |

Two snapshots in a row with no failure in between work on master, so the failure comes from the failed snapshot. With only the abort, the second Vanara snapshot came after 51 s and 3.6 min; with the abort and the release, after 8 s (one run), so the release is kept.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
