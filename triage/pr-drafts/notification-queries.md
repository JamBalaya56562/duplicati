Reading, dismissing and registering a notification loaded every notification from the database, and each dismissal signalled its own update. With thousands of notifications (#4719) every one of these calls got slower as the list grew.

- `Connection.GetNotification(id)` reads one notification by ID; `NotificationService` uses it.
- `DismissNotification` deletes by ID and computes the unacknowledged warning/error flags with `EXISTS` instead of loading the list. `NotificationService` returns NotFound from its result.
- `RegisterNotification` only loads the list when the conflict handler enumerates it. The handler's parameter type changes from `INotification[]` to `IEnumerable<INotification>`.
- `DismissNotificationsForBackup(backupId)` removes a backup's notifications in one transaction and signals one update. `Runner` does not use it yet: the cleanup loop there also changes in the PR that replaces a backup's notification on every run, so switching it to this method follows once that is merged.

Measured per call (ms), before → after, with 200 / 2,000 / 10,000 notifications. These were taken one after the other on a machine under full CPU load, so they are for comparison only:

| | 200 | 2,000 | 10,000 |
|---|---|---|---|
| register | 67 → 49 | 153 → 43 | 403 → 37 |
| get | 18 → 2 | 63 → 2 | 337 → 1 |
| dismiss | 84 → 68 | 230 → 65 | 813 → 68 |

Removing 100 notifications for one backup with the new method took about 70 ms and signalled one update instead of 100.

Tests: `NotificationQueryTests` (new, 5 tests). Before the change, dismissing a backup's 20 notifications signalled 20 updates (expected 1). `ServerDatabaseLockingTests` (3) and `ServerBackupLifecycle_Async` pass. The build reports no new warnings in the changed files.

Related to #4719

🤖 Generated with [Claude Code](https://claude.com/claude-code)
