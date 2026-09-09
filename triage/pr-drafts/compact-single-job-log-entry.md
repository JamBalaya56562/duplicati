Branch: `fix/compact-single-job-log-entry` (JamBalaya56562/duplicati)
Title: Log a compact once in the job log

## Summary

Running `compact` on its own when it has something to do shows the run twice in the job log, and with `--auto-vacuum` the database is vacuumed twice.

Since the result handling was moved into the `Controller` ([7f008341df472d5f5d7a78d11b60872ae6bd1055](https://github.com/duplicati/duplicati/commit/7f008341df472d5f5d7a78d11b60872ae6bd1055)), the `Controller` writes the result of every operation to the job log and runs auto-vacuum afterwards. `CompactHandler.RunAsync` still did both itself whenever the compact changed something. It is the only handler that still writes its own result. So that run got two `Result` rows for the same operation, and two `Vacuum` operations.

This change ([44e5714ab89af509ae0e45369686b8eb5adf15fe](https://github.com/JamBalaya56562/duplicati/commit/44e5714ab89af509ae0e45369686b8eb5adf15fe)) removes the write and the vacuum from `CompactHandler.RunAsync`, and leaves both to the `Controller`, as for every other operation. Compacts run as part of backup, delete and purge use `DoCompactAsync` and are not affected.

## Testing

New `CompactResultLogTests`: two backups leave half the data unused, then a standalone compact deletes volumes.
- `ACompactThatChangesSomethingIsLoggedOnceAsync`: before the fix there were 2 `Result` rows with `MainOperation` `Compact` (Expected: 1, But was: 2); after the fix there is 1.
- `AutoVacuumRunsOnceAfterACompactAsync`: with `--auto-vacuum=true`, before the fix there were 2 `Vacuum` operations (Expected: 1, But was: 2); after the fix there is 1.

Also ran `Issue6200`, `FailedOperationDatabaseTests`, `CompactBlockVolumeIdConstraintTests`, `AutomaticIndexTests` and `VacuumAndBugReportTests`: 12 passed (including the two new tests), 0 failed. No new build warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
