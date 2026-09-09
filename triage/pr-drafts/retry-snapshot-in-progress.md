# Retry a snapshot while another shadow copy is being created

Fixes #5570

Only one shadow copy can be created at a time. A backup that started while another program was creating one failed with "Failed to create a snapshot: The creation of a shadow copy is already in progress", even with `--snapshot-policy=required`. VSS itself says what to do: the AlphaVSS documentation of `VssSnapshotSetInProgressException` reads "Either wait to try again or return with a failure".

With this change:

- `WindowsSnapshot` tries the snapshot again every 10 seconds, until `--vss-timeout` (10 minutes by default) has passed, and then fails with the VSS error as before. Each attempt uses a new snapshot manager, and the failed one is released, as the existing retry with the Microsoft software provider already does. Each retry is logged at the information level.
- The error is recognised by its HRESULT, `VSS_E_SNAPSHOT_SET_IN_PROGRESS` (0x80042316), which the native and Vanara providers pass on, or by AlphaVSS's `VssSnapshotSetInProgressException`.
- The WMI provider logged any failed `Win32_ShadowCopy.Create` as an error and then failed with a general `InvalidOperationException`, so a later successful attempt would still have left an error in the result. Return value 9, "another shadow copy operation is already in progress", now gives the same VSS error, without the log.

## Testing

New tests in `WindowsSnapshotTests`, with the fake snapshot provider the file already uses and a short wait between attempts:

| test | master | with the change |
|---|---|---|
| `ASnapshotIsRetriedWhileAnotherIsInProgress` (the first two attempts fail with 0x80042316) | fails on the first attempt | the third attempt succeeds, the first two providers are released |
| `ASnapshotStillInProgressFailsAfterTheTimeout` (every attempt fails, `--vss-timeout=1s`) | one attempt | several attempts, then the VSS error, every provider released |

`WindowsSnapshotTests` and `WindowsSnapshotFailureTests`: 4 passed, 2 skipped (they need an elevated process). `Duplicati.Library.WindowsModules` builds with no warnings.

Not run: two real snapshots at once, which needs an elevated process, and the WMI return value 9, which comes from the documentation of `Win32_ShadowCopy.Create`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
