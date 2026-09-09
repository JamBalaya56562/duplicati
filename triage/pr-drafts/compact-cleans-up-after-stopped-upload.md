# Let compact clean up after an operation stopped mid-upload

An operation that is stopped while it uploads (killed, power loss) leaves a volume in the `Uploading` state and sets the flag that uploads were active. The next backup verifies the destination with `VerifyAndClean`, sees the flag, and cleans that up. A standalone `compact` always verified strictly, so it stopped instead:

```
The operation Compact has failed => The missing remote volume duplicati-b....dblock.zip is in uploading state and strict mode is on
The operation Compact has failed => The remote volume duplicati-b....dblock.zip is in uploading state, partially uploaded, and strict mode is on
```

The message does not say what to do. It keeps failing until a backup or a repair has run.

With this change, when the flag is set, compact first runs the same cleanup a backup would. It runs before compact plans what to compact, so the plan is made from what the destination holds. Without the flag, nothing changes, and an unexpected uploading volume still stops compact as before.

## Testing

- New `CompactAfterInterruptedUploadTests`. The state a stopped upload leaves is a block volume registered as `Uploading` that is not at the destination.
  - `CompactCleansUpAfterAStoppedUploadAsync` sets the flag that uploads were active. It fails on master with the error above, and passes with the change: the volume is gone from the database, and `test all` passes.
  - `CompactStillRefusesAnUnexpectedUploadingVolumeAsync` leaves the flag unset. It still gets `UnexpectedUploadingFile`, on master and with the change.
- The compact and delete tests (`CompactBlockVolumeIdConstraintTests`, `CompactDisruptionTests`, `CompactResultLogTests`, `DryRunTests`, `FailedOperationDatabaseTests`, `Issue6200`, `Issue6254`, `LockingDeleteAndCompactTests`, `SoftDeleteTests`): 33 passed.
- The CLI on Windows, killing `compact` at a random point 0.3 to 3.5 seconds in, then running `compact` again (30 to 40 rounds per run):

  | | runs | rounds | the follow-up compact failed |
  |---|---|---|---|
  | master | 2 | 70 | 12 |
  | this change | 3 | 120 | 0 |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
