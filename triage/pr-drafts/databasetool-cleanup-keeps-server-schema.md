## Summary
`DatabaseTool cleanup` deletes every database that `verify` reports as **Orphaned**, meaning it is referenced neither by `dbconfig.json` nor by the server database's `Backup` table. A database with the server schema is never referenced from either place, so it is always reported as orphaned. That covers:
- the active `Duplicati-server.sqlite`
- the `backup Duplicati-server <yyyyMMddHHmmss>.sqlite` copy that `DatabaseUpgrader` keeps before a schema upgrade. The `backup` prefix is localized, e.g. `バックアップ` on a Japanese system. This copy is what users restore from when a server upgrade goes wrong.

The orphan logic came in with [`8b2475ee93c5`](https://github.com/duplicati/duplicati/commit/8b2475ee93c502ae20cf21bbbf76c9448d00739e) (#6796).

Reproduced with the real upgrade path on master:
1. Created a server DB by starting `Duplicati.Server` and a local DB by running a CLI backup.
2. Lowered their schema versions with `DatabaseTool downgrade`.
3. Restarted the server and ran a CLI `find` against the local DB.

`DatabaseUpgrader` then left one upgrade copy of each. `verify` listed both copies as Orphaned (`Type: Server` and `Type: Backup`), and `cleanup --force` reported `Deleted: 2 file(s)`.

## Change
`cleanup` now skips every orphaned database whose type is `Server`. Orphaned local and sync databases are still deleted. `verify` output is unchanged.

This also keeps `cleanup` from deleting the active server database. That part is independent of #<PR for fix/databasetool-keeps-server-db>, which makes `verify` report it as `Found`. The two branches do not conflict.

## Tests
New `DatabaseToolTests.TestCleanupKeepsServerSchemaDatabasesAsync`. It runs `cleanup --force` through `Program.MainAsync` on a folder that holds:
- an active server DB
- a `backup Duplicati-server <timestamp>.sqlite` copy with the server schema
- a `backup ORPHANXYZ <timestamp>.sqlite` copy with the local schema

It asserts that the two server-schema files remain and the local copy is deleted.

The new test failed before the change (`Active server DB should not be deleted`) and passes after it. The existing `TestCleanupCommandAsync` cases still pass. Filter: `FullyQualifiedName~DatabaseToolTests.TestCleanup`, 3/3.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
