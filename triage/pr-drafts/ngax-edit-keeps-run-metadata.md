Fixes #3018

The edit page of the old UI sends back the whole backup it loaded, including its metadata, which holds the results of the last run. If the backup finishes while the page is open, saving writes the old results back, so the backup looks as if it had not run.

The server keeps the stored metadata when none is sent, which is what the new UI relies on. The old UI now leaves the metadata out when it saves an existing backup.

## Testing

New Playwright test `ngaxEditKeepsMetadata.spec.ts`. On a fork CI run with only the test, it failed because the page sent the old `LastBackupDate`. With the change, all 22 Playwright tests passed. Those runs were on an older master; this PR's CI runs it on the current one.

I did not run it locally.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
