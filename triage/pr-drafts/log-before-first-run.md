## Summary
Closes #1814.

Showing the log of a backup that had not run yet failed with "no such table: LogData". The log endpoint now returns an empty list when the database does not exist yet, and when it exists without the `LogData` table (https://github.com/duplicati/duplicati/commit/76d082480f8b0b8c9a2f4a6066c9ea39f2546f2f). No test called the endpoint for a backup that has not run. This PR only adds a test.

## Testing
- New test `ServerApiIntegrationTests.TheLogOfABackupThatHasNotRunIsEmpty_Async`. It creates a backup and asks for its log, first with no database, then with a database that has no `LogData` table. Without the check for the table it fails: `Expected: OK`, `But was: InternalServerError`. On master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
