# Issue 本文案: バックアップ以外の操作の通知（2026-10-22、未投稿）

- 利用者の判断: コードは変えず、Issue 本文の案だけ作る（投稿はしない）
- 根拠: runner-dismiss-followups.md の観測（使い捨てのテスト、master + fix/runner-dismisses-backup-notifications-once）

---

Title: Notifications from verify, compact and repair pile up, and a successful backup clears them

## Description

Since #6421, a backup run clears the earlier notifications of its backup and adds a new one only if the run has a warning or an error (#6420). Other operations started on a backup (verify, compact, repair, vacuum, purge, ...) take the other branch in `Runner.UpdateMetadataBase`: they add a notification on a warning or error and never clear one.

This gives three behaviours that may not be intended:

1. Running the same operation again with the same warning adds the same notification again. Three verify runs with one warning leave three identical notifications.
2. When the operation later succeeds, its earlier warning or error stays until it is dismissed by hand.
3. The next successful backup clears every notification of that backup, including an error from a verify run that may not be fixed yet. The backup clears by `BackupID` only, as the notification does not record which operation produced it.

These operations are not scheduled (the scheduler only queues backups), so (1) grows only as fast as people run them by hand or through the API.

## Steps to observe

Calling `Runner.UpdateMetadataBase` for one backup with results in this order, and counting that backup's notifications after each call:

| Result passed | Notifications for the backup |
|---|---|
| verify with one warning, three times | 3 (the same text) |
| verify without warnings | 3 |
| verify with one error | 4 |
| backup without warnings | 0 |

## Question

Which of these would you like?

- A. Keep it as it is: only backups clear notifications, as #6420 asked.
- B. Do not add a notification when the backup already has one of the same type, title and text (done in the conflict handler, no schema change). This fixes (1) only.
- C. Record which operation produced a notification, and have each run replace that operation's earlier notification, also on success. This fixes (1) and (2), and lets a backup leave other operations' notifications alone for (3). It needs a new column, or reusing an existing one, and does not cover notifications already stored.

I can open a PR for B or C if one of them fits.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
