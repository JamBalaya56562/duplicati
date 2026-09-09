## Summary
`DatabaseTool verify` reported the server database (`Duplicati-server.sqlite`) as **Orphaned**, because it is referenced neither by `dbconfig.json` nor by its own `Backup` table. `cleanup` deletes every orphaned database, so `cleanup --force` deleted the live server database (observed with 2.4.0.1 against a data folder created by the 2.4.0.1 server: `Found 2 orphaned database(s): <data>\Duplicati-server.sqlite, <data>\local.sqlite`).

## Change
In `Verify.AnalyzeDatabasesAsync`, the server database in the data folder is now reported as `Found` with source `server database`. `cleanup` uses `GetOrphanedDatabasesAsync`, which is built on the same analysis, so the server database is no longer a deletion candidate.

## Tests
New `DatabaseToolServerDatabaseTests` (server DB created with the real server schema via `DatabaseUpgrader`):
- `GetOrphanedDatabasesAsync` does not return the server database
- `AnalyzeDatabasesAsync` reports it as `Found` / `Server`
- `cleanup --force` through `Program.MainAsync` leaves it on disk

All three failed before the fix (cleanup printed `Deleted: ...\Duplicati-server.sqlite`) and pass after it; the existing `TestVerify*` / `TestCleanup*` tests still pass.

Manually: on a data folder created by starting `Duplicati.Server`, `cleanup --dry-run` now prints `No orphaned databases found.`

Once this is released, the warning added to `databasetool.md` in duplicati/documentation#37 can be removed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
