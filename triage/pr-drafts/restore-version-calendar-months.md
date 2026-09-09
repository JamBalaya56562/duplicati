## What happens

The version list on the restore page of the old web UI (`ngax`) groups the versions under "Today", "Yesterday", "This week", "This month", "Last month" and then the year. `createGroupLabel` in `RestoreController.js` counted the month groups back from today:

- "This month" held the versions from 8 days to one month ago.
- "Last month" held those from one to two months ago.

So a version from late last month showed under "This month", which is what the report shows: the last four weeks all under "This month".

The month was counted back with `new Date().setMonth(now.getMonth() - 1)`, which also overflows from the 29th to the 31st. On March 31 it lands on March 3, and on May 31 on May 1. Near the end of a month, almost all of the current month was listed under "Last month".

## The change

"This month" and "Last month" now start on the first day of the current and the previous calendar month (`new Date(year, month, 1)` and `new Date(year, month - 1, 1)`, which also handles January). This is what the headings say, so the existing translations of the headings still fit; changing the wording instead would have dropped them. "This week" stays the last 7 days: a calendar week would depend on the first day of the week, which differs between locales.

The new UI does not group the versions like this, so it is not affected.

## Red to green

There is no test framework for the `ngax` scripts. To check the logic, I ran `createGroupLabel` from master and from this branch with a fixed "today" and 13 version dates:

| Today | Version | Expected | Before | After |
|---|---|---|---|---|
| 2026-03-20 | 2026-02-25 | Last month | **This month** | Last month |
| 2026-03-20 | 2026-01-31 | 2026 | **Last month** | 2026 |
| 2026-03-31 | 2026-03-02 | This month | **Last month** | This month |
| 2026-01-15 | 2025-12-20 | Last month | **This month** | Last month |
| 2026-01-15 | 2025-11-30 | 2025 | **Last month** | 2025 |
| (8 other cases: today, yesterday, this week, this month, the last 7 days reaching into the previous month) | | | same | same |

Before: 5 of 13 wrong. After: 0 of 13 wrong.

I also opened the restore page of a backup with two versions in a browser, with the web root from this branch: it shows "Latest" and "Today", and there are no script errors.

Fixes #5832

🤖 Generated with [Claude Code](https://claude.com/claude-code)
