Part of #5242

## Summary
In #5242, ts678 noted that the recovery tool help only mentions `--exclude`, and the answer was that the filters work as in the normal command line. They do not for a filter with only include rules. A normal restore leaves out the files that no rule matches when there are only include rules (`FilterExpression.Matches`). The recovery tool called the filter's own `Matches` and returned every file that no rule matched, so `restore --include=*.txt` restored all files, and `list` listed them all.

`EnumerateFilesInDList`, which both `list` and `restore` use, now calls `FilterExpression.Matches`. Exclude-only and mixed filters give the same result as before. The help now names `--include` next to `--exclude`.

## Testing
- New test `RecoveryToolTests.IncludeFilterSelectsOnlyTheMatchingFilesAsync`. It backs up `a.txt` and `b.dat`, downloads and indexes the backup with the recovery tool, and restores with `--include=*.txt`. On master it fails with `Extra (1): < "b.dat" >`. With the change it passes.
- Tests matching `RecoveryTool`: 16 passed, 1 skipped (the open-files test runs on Linux and macOS only). No new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
