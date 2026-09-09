## Summary

After a backup run, `Runner.UpdateMetadataBase` removes the notifications of the backup's earlier runs (#7484). It read all notifications, then dismissed them one by one, so a backup with N pending notifications wrote N transactions and sent N notification updates to the UI.

#7512 added `Connection.DismissNotificationsForBackup`, which deletes the same set (every notification whose `BackupID` matches, of any type) in one transaction and signals one update. This switches the loop to it ([718e18a](https://github.com/JamBalaya56562/duplicati/commit/718e18a574730b8d02178c63d0a9921e3915ab12)). The failure is still logged with `LogError`, as before.

`UpdateMetadataBase` is made `internal` so the test can call it.

## Testing

- `NotificationQueryTests.BackupRunDismissesTheNotificationsOfTheEarlierRunsWithOneUpdate` puts five notifications on a backup and one on another, runs `UpdateMetadataBase` with a backup result, and expects only the other backup's notification to remain, with one notification update. It fails on master (`Expected: 1  But was: 5`) and passes with this change.
- The other `NotificationQueryTests` and `BackupWarningReplacesTheNotificationOfTheEarlierRun` (from #7484) still pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
