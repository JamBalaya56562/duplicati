# Run database upgrades in a transaction

`DatabaseUpgrader` upgrades the server database, the local databases of the jobs and the sync databases. It ran the upgrade statements one by one, outside of a transaction, and set the version at the end. When a statement failed, it closed its connection and copied the database it had saved before the upgrade back over the database file:

- If another connection had the database open, the copy either failed (on Windows: "The requested operation cannot be performed on a file with a user-mapped section open") and left the database with half of the upgrade applied under the old version, or replaced a database that was in use. The `-wal` file was left as it was.
- Two processes that opened the same old database at once both ran the upgrade, and the second one failed on the changes of the first. In a probe that upgraded a server database from two connections at once, 50 times on Windows, one of the two always failed, and twice the upgrade was lost.

With this change:

- The upgrade runs in one write transaction. The version is read again once the lock is taken, so a second process waits for the first one (the busy timeout is 10 seconds) and then finds the database upgraded.
- A failed upgrade is rolled back. The saved copy is still made before the upgrade, but it is no longer copied back.
- An upgrade through a script that begins, commits or vacuums on its own cannot run inside a transaction, and runs as before. Only the old `6. Optimize FileSetEntry-Table.sql` of the local database does that (checked by a test over all the scripts).

The code upgrade hooks (`DbUpgradesRegistry.CodeChanges`) get the connection, and their commands would need the transaction. The registry is empty.

This complements #<server instance check PR>, which stops a second server before it opens the database. This change covers the other users of the upgrader, and any two processes that open the same database.

## Testing

New tests in `DatabaseUpgraderTests`:

- `UpgradeDatabase_FromTwoConnectionsAtOnce_BothSucceedAsync`: upgrades a database one version behind from two connections at once, 10 times. On master one of them fails in the first run (the copy back fails with the user-mapped section error); passes with the change.
- `UpgradeDatabase_ThatFails_LeavesTheDatabaseAsItWasAsync`: a database two versions behind, where the last upgrade fails, upgraded while another connection has it open. On master the table of the first upgrade is left in the database at the old version; with the change the database is as it was.
- `UpgradeDatabase_OnlyScriptsWithTheirOwnTransactionRunWithoutOne`: only version 6 of the local scripts is run without a transaction, and a trigger body is not taken for a transaction.

`DatabaseUpgraderTests`, `DatabaseTool*Tests`, `RepairHandlerTests`, `Issue6909`: 83 passed on Windows. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
