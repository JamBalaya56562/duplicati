A backup whose `--log-file` is inside the source backs up that log file too, although it is written to while the backup runs (#1443).

## The change

`BackupHandler.GetBlacklistedPaths` now adds the `--log-file` path, made full with `Path.GetFullPath`, because the option can be relative and the controller opens it from the current folder. The list is used by backup, sync and `test-filters`, so the log file is left out of all of them. A file of the same name in another folder is still backed up.

The log file of the server process (`--log-file` given to the server) is not a job option and is not covered.

## Testing

New tests in `BackupExcludesLogFileTests`:

| test | master | this branch |
|---|---|---|
| `TheLogFileOfTheBackupIsNotBackedUp(false)` (absolute path) | **fail**: the log file is in the backup | pass |
| `TheLogFileOfTheBackupIsNotBackedUp(true)` (relative path) | **fail**: the same | pass |
| `AnotherFileWithTheSameNameIsBackedUp` | pass | pass |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `BackupExcludesLogFileTests`, 3 passed. Before the rebase, the tests of exclusion, sync, filters and the controller, 78 passed. No warnings in the changed files.

Fixes #1443

🤖 Generated with [Claude Code](https://claude.com/claude-code)
