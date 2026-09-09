Branch: `test/playwright-wait-for-backup-save` (from master 922a7c73750fd04295ed3bae8ebc3f8832ab227b)
Title: Wait for the backup to be saved in the Playwright test
Merge order: independent. Also changes `playwright-tests/backupRestore.spec.ts`, like `test/playwright-exact-menu-action`; the two merge without conflict (checked with jj).

## Summary

In `backup and restore flow`, `createBackup` presses Submit and returns, and `runBackup` goes to the home page right away. When saving takes a moment, leaving the page cuts the `POST /api/v1/backups` request short, the backup is not saved, and the test fails later while waiting for the backup's Start button:

```
TimeoutError: locator.click: Timeout 30000ms exceeded.
  - waiting for locator('div.backup').filter({ hasText: 'PlaywrightBackup' }).locator('button').filter({ hasText: 'Start' })
```

In the trace of such a run, the `POST /api/v1/backups` request has no response, and the home page shows "No backups found".

`createBackup` now waits for the response to that request after pressing Submit and checks that it succeeded.

Commit: [79add9df62b43684d9d1293fd5608a89a4efc679](https://github.com/JamBalaya56562/duplicati/commit/79add9df62b43684d9d1293fd5608a89a4efc679)

## Testing

To make the timing reproducible, the save request was delayed by 3 seconds for the check only (a `page.route` for `POST /api/v1/backups` inserted at the start of the test, not part of the change). Local server started like the CI job, Node 26.12.0, Playwright 1.64.1:

- Before (master spec): fails with the timeout above (`backup and restore flow`, 56.7 s).
- After: passes (52.8 s).

The failure also happened without any delay, in one of four runs of the suite on Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
