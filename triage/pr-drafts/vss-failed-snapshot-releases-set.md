Fixes #7005
Fixes #6866

## What happens

A Windows snapshot that fails after its snapshot set was started leaves the set in progress. That happens, for example, when one source is on a volume that cannot be snapshotted: `SnapshotManager.InitShadowVolumes` calls `StartSnapshotSet`, then `CheckAndAddSupportedVolumes` throws "Drive not supported for snapshot". Every later snapshot then fails with `VSS_E_SNAPSHOT_SET_IN_PROGRESS` (0x80042316) until the process ends. For the server, that is every backup until it is restarted. With the Vanara provider it shows as a `NullReferenceException` in `CVssBackupComponents.StartSnapshotSet` instead.

It is not limited to the process: a set left in progress by one process still made the first snapshot of the next process fail a few minutes later, as #7005 says of other VSS applications.

#7419 disposes the `SnapshotManager` when its setup throws, but neither the Native provider (the default) nor the Vanara provider aborts a set that was started and not created. On Windows 11, releasing the Native components happened to end the set; on Windows Server 2025 it does not.

## The change

`NativeVssBackup` and `VanaraVssBackup` call `AbortBackup` on dispose when the set was started but `DoSnapshotSet` did not complete. `VanaraVssBackup` also releases the backup components.

## Checked

`WindowsSnapshotFailureTests.ASnapshotAfterAFailedSnapshotWorks` (new) takes a snapshot of a folder, then one with an extra source on a drive letter that is not in use, which fails after the set is started, then one of the folder again, with the Native and the Vanara provider. VSS needs an elevated process, so it is ignored when the process is not elevated, or when no snapshot can be made at all.

On a GitHub Windows Server 2025 runner (elevated), running only this test, three times each: Native alone, Vanara alone, and both in one process:

| | Native | Vanara |
|---|---|---|
| Vanara abort only (the first version of this PR) | **fails** with `0x80042316` on the first run; every later run is skipped because even the first snapshot can no longer be made | skipped (same cause) |
| this PR | passes 6 of 6 | passes 6 of 6 |

That is the failure the first CI run of this PR showed for Native.

On Windows 11, from an elevated shell, both versions pass every run (Native alone and both in one process, twice each), so the Native part cannot be seen there. Before #7419 and this change, Windows 11 failed too: the third snapshot threw `COMException (0x80042316)` with Native and `NullReferenceException` with Vanara.

The build reports no warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
