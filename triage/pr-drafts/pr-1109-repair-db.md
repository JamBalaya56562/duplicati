In #2265, repair could not recreate a local database that could not be read (`table "Operation" already exists`).

Repair sets such a database aside and recreates it from the remote files (`RepairHandler`), but on master it never gets there. Before any operation starts, `Controller.RestoreOptionsFromExistingDatabase` reads the options stored in the local database, and an exception there stops the operation. A file that is not a database fails with `SQLite Error 26: 'file is not a database'`, and a database without the version table fails with the error from the issue.

## The change

For a repair, a database that cannot be opened there is logged at the information level (`SkipOptionsFromUnreadableDatabase`), and the repair goes on without the stored options. Other operations still stop with the error.

The 2017 report also says that the database could not be moved because it was still open. With `Pooling=false` that no longer happens: the test moves it.

## Testing

New `RepairHandlerTests.RepairSetsAsideAnUnreadableDatabaseAndRecreatesItAsync`:

| test | master | this branch |
|---|---|---|
| `("garbage")`: a file that is not a database | **fail**: `file is not a database` | pass: set aside with the same bytes, recreated |
| `("tables-without-version")`: the error from #2265 | **fail**: `table "Operation" already exists` | pass: set aside, recreated |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `RepairHandlerTests`, 25 passed. No warnings in the changed files.

Refs #2265 (the issue also covers other points).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
