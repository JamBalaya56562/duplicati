## What happens

`ServerApiIntegrationTests` start the server in the test process. Each test creates a data folder of its own and passes it twice: as `--server-datafolder` in the server arguments, and in the legacy `DUPLICATI_HOME` variable. In Debug builds, the server used neither:

- `ApplicationSettings` reads the data folder in its constructor through `DataFolderManager.GetDataFolder`, which looks at the process command line (`Environment.GetCommandLineArgs()`), not at the arguments given to `Program.Main`.
- Debug builds default to portable mode, and portable mode wins over `DUPLICATI_HOME`.

So every test used `bin/Debug/net10.0/data/Duplicati-server.sqlite`, shared with the other tests and with earlier runs. Whatever one test left there was there for the next. For example, a pause saved by a test that was stopped half-way made the next runs start with the server paused.

`DataFolderManagerIdTests` and `CLIDatabaseLocatorTests` already avoid this by also setting `DUPLICATI__PORTABLE_MODE=false`.

## The change

`WithAuthenticatedServerAsync` in `ServerApiIntegrationTests`:

- Sets `DUPLICATI__PORTABLE_MODE=false` while the server runs, as the data folder tests do, and restores it afterwards.
- Checks that the server database was created in the folder of the test.
- Closes the server database and clears the SQLite connection pool before removing the folder. Once the database is in the test folder, the folder could not be removed: the server registers its `Connection` as an existing instance, which the service container does not dispose, and the shutdown does not close it either (a process that stops exits).

The change is in the tests only.

## Red to green

| | Before | After |
|---|---|---|
| The server database is in the test folder | **red**: `The server did not keep its database in the test data folder, but in ...\UnitTest\bin\Debug\net10.0\data\` | green |
| `ServerApiIntegrationTests` | | 8 passed |
| Test folders left behind after the class | | 0 (with only the pool cleared, 8 were left, one per test) |
| The shared `bin/.../data` database | written by every test | not written by the run |

Measured on Windows, when the class had 8 tests. On today's master, which added more tests to the class (#7365, #7391), all 12 pass with this change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
