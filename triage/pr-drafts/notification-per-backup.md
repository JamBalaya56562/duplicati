
A backup that ends with a warning or error adds a notification without removing the one from its earlier run. A backup that warns on every run therefore gathers one more notification per run, which in #4719 reached thousands and made "dismiss all" hang the browser.

#6420 asked for a backup's pending notifications to be cleared after each run, and a new one to be emitted if the run has a warning or error. #6421 implemented the clearing only for runs with neither. This moves the clearing before the check, so only the latest run's notification is shown.

Other operations (verify, compact, ...) keep their current behaviour, as they never cleared notifications on success either.

Testing: `BackupWarningReplacesTheNotificationOfTheEarlierRun_Async` runs a backup that warns on every run three times and expects a single warning notification for it, with the other notifications untouched. It fails on master (three notifications) and passes with this change.

Related to #4719

🤖 Generated with [Claude Code](https://claude.com/claude-code)
