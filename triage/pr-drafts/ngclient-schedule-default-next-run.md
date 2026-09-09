## Summary

A new backup's schedule, and the schedule presets, could start in the past:

- The new backup default comes from `/api/v1/backupdefaults` (`newbackup.json`: `"Time": "13:00:00"`, no date). `mapScheduleToForm` kept the date from `SCHEDULE_FIELD_DEFAULTS()`, which is today's date. After 13:00 local time that is already in the past.
- `BackupState` is a root singleton, so that date is fixed when the state is created and only reset on exit. If the UI stays open past midnight, the default starts on an earlier day.
- The presets (`SCHEDULE_DEFAULT_OPTIONS`) compute their dates when the module loads, so picking "Daily 13:00" later uses that day.

The server runs a schedule whose start is in the past as soon as it is saved. `LastRun` defaults to `DateTime(0)` because ngclient doesn't send it, `GetNextValidTime` returns the past start unchanged, and the scheduler queues the backup when `start <= UtcNow`. So saving a new backup in the afternoon started it at once. The old UI avoided this: `EditBackupController.js` uses today 13:00 and moves it to tomorrow if it has passed.

Changes:

- Add `getNextRunDate(time)`: today if the time of day is still ahead, otherwise tomorrow.
- `mapScheduleToForm`: a time without a date (the server default) starts at `getNextRunDate(time)`.
- `updateScheduleType`: compute the date when a preset is picked (`getNextRunDate`, or the next Monday for the weekly preset) instead of using the module-load date.
- Leave `nextTime.date` out of the preset matching in `mapScheduleToForm`. The date is only the first run, and keeping it would show "Custom" for a new backup created after 13:00.

Commit: [c73dbe724eb61db63c580a8b3582c4c1b669ca4b](https://github.com/JamBalaya56562/ngclient/commit/c73dbe724eb61db63c580a8b3582c4c1b669ca4b)

## Testing

`ng test ngclient --watch=false --include 'projects/ngclient/src/app/backup/backup.state.spec.ts' --include 'projects/ngclient/src/app/backup/schedule-v2/*.spec.ts'` (TZ Asia/Tokyo, `Date` faked to 2026-10-20):

- New tests:
  - `BackupState server schedule defaults`: at 10:00 the start is today, at 15:00 it is tomorrow, and the type stays `daily` in both cases.
  - `ScheduleComponent`: picking `daily` at 15:00 gives tomorrow, and `weekly` gives the next Monday.
- Before the fix, the 3 tests fail with the date from when the state or module was created (`expected '2026-10-11' to be '2026-10-20'` / `'2026-10-21'`).
- After the fix, 26/26 pass, including the 2 boundary tests for `getNextRunDate` (12:59:59 keeps today; 13:00:00 moves to 2026-11-01 from 2026-10-31).
- `tsc --noEmit` passes for the app and spec tsconfigs, and Prettier passes.

Server behaviour, checked against a live `Duplicati.Server` built from duplicati master f921ee53 (fresh data folder, loopback only). At 2026-10-11 17:18 JST (08:18Z) I POSTed `/api/v1/backups` twice with the schedule shape ngclient sends (`Repeat: 1D`, all days, no `LastRun`):

| Backup | `Schedule.Time` | Result |
| --- | --- | --- |
| past (what ngclient sent before this change) | `2026-10-11T04:00:00.000Z` (today 13:00 JST) | Started at 08:18:08Z, 2 s after saving, and wrote dlist/dblock/dindex to its target. `LastRun` = `2026-10-11T08:18:06Z` |
| future (what ngclient sends now) | `2026-10-12T04:00:00.000Z` (tomorrow 13:00 JST) | Did not run within 2 minutes. Target empty, `LastRun` = `0001-01-01T00:00:00Z` |

🤖 Generated with [Claude Code](https://claude.com/claude-code)

<!-- Extra testing evidence for the PR body if wanted (2026-10-11, after rebase onto main 0.0.243):
End-to-end through the UI: `ng serve` against a live Duplicati.Server (master 85d15280), at 21:00 JST, creating a new backup with the default "Daily 13:00".
- This branch: the form date was 2026-10-12. It saved `Time: 2026-10-12T04:00:00Z` and did not run (checked for over 2 minutes).
- Upstream main 0.0.243: the form date was 2026-10-11. The backup started 3 s after Submit (12:20:50Z) and wrote 3 files to its target.
-->
