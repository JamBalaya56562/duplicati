# Check for a running server before opening the server database

The server opened its database before it checked that no other server was running (`Program.Main`: `GetDatabaseConnection`, then `--configure-https` and the certificate renewal, and only then `CreateApplicationInstance`). Opening the database creates or upgrades it, so two servers started at the same time, such as from two startup entries, upgraded the same database at once:

- `DatabaseUpgrader` runs the upgrade statements one by one, without a transaction, and sets the version at the end.
- When one of them fails, it closes its connection and copies its copy of the old database back over the database file, which the other server is using. The `-wal` file is left as it is.

A probe that upgraded a version 11 server database from two connections at once, 50 times on Windows:

| runs | result | error of the other connection |
|---|---|---|
| 48 | version 12, `OperationType` present | copying the old database back failed, as the file was open ("user-mapped section") |
| 2 | **version 11, column missing: the upgrade was lost** | both made the copy of the old database under the same name in the same second |

This looks like [forum 22694](https://forum.duplicati.com/t/22694): after an update to 2.4.0.0 the server failed to start with `no such column: "OperationType"` while the `Version` table said 12, and the user later found two Duplicati startup entries. The probe did not produce that exact state, so this is a likely cause, not a confirmed one.

The check for a running server now comes first, so a second server stops before it opens the database. The data folder is prepared, locked down, before the check, because `SingleInstance` would otherwise create it with the default permissions, and `PrepareSecureDataFolder` would then reject a folder it did not create.

One small difference: with `--webservice-dont-autocreate-database` and no database, the data folder is now created (locked down) before the server stops with the missing database error.

## Testing

- New `ServerApiIntegrationTests.ASecondServerDoesNotTouchTheDatabaseAsync`: holds the instance lock of an empty data folder and starts a server there. On master the server stops with `MultipleInstanceException`, but only after creating the database (red). With the change the database is not created.
- `ServerApiIntegrationTests`, `EncryptedFieldsWarningTests`, `NotificationQueryTests`, `UnackedFlagSettingTests`, `SuspendResumeStateTests`, `WebServerLoaderWebrootTests`, `DatabaseUpgraderTests`: 51 passed on Windows. No new warnings in the changed files.

The upgrader itself (no transaction, copying the old file back over a database in use) is not changed here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
