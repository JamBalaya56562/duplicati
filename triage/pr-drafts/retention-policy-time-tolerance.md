Fixes #3987

A version is kept by `--retention-policy` only when it is at least the full interval after the previous kept one. A weekly or daily scheduled backup that starts a few seconds later than the one before it is therefore deleted by a `1W` or `1D` interval.

The intervals now get the tolerance `--keep-time` already has: 1% of the interval, at most one hour. `--disable-time-tolerance` turns it off as it does for `--keep-time`, and its help text says so.

## Testing

New `DeleteHandlerTests.RetentionPolicyAllowsATimeToleranceOnTheInterval`, with and without `--disable-time-tolerance`. It failed on an older master without the change. On the current master, all 6 tests in `DeleteHandlerTests` pass on Windows. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
