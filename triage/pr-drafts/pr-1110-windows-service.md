In #7740, the server crashed while the Windows service started it after an MSI upgrade, and the service then stayed stopped. Windows saw a normal stop: nothing was logged as a failure and no recovery action ran.

The service runs the server in-process. When the server fails to start, `Server.Program.Main` returns 100, but `Runner.RunInProcess` dropped the return value and `ServiceControl` reported `SERVICE_STOPPED` with exit code 0. Only the out-of-process path restarts the server, after 10 seconds. The installers set no recovery actions for the service.

## The change

- The runner keeps the exit code of an in-process run that ended on its own with a non-zero code, and passes it to the stopped callback.
- The Windows service then writes an error to its event log and reports exit code 1067 (`ERROR_PROCESS_ABORTED`).
- A requested stop still reports exit code 0. So does the exit that the server makes so that an update can replace the files (return code 0), so the recovery actions do not race the update helper, which starts the service again itself.
- The server also returns the crash code (the new `EXITCODE_CRASHED`, 100, which replaces the two existing literal 100s) when the webserver stops with an exception after it has started. Before, that returned 0.
- The TrayIcon and Agent MSIs set recovery actions for the service: restart after 60 seconds, twice, and reset the count after a day. They also set the flag that runs the actions for a non-zero exit code (`MsiServiceConfigFailureActions`, and `MsiServiceConfig` with `SERVICE_CONFIG_FAILURE_ACTIONS_FLAG`). The already scheduled `MsiConfigureServices` processes both. wixl 0.106 has no `ServiceConfigFailureActions` element, so the rows are in `InstallTables.sql`, like the delayed start.

This does not explain why the server in #7740 could not load `System.IO.Compression`, so it does not close that issue.

## Testing

On Windows 11, as an administrator (`Duplicati.WindowsService.exe SERVER` installed as a test service, with `sc failure` set to restart twice and `sc failureflag 1`, and the port held so that the server fails to start, as in #7740):

| build | after 40 s | Service Control Manager events |
|---|---|---|
| master | `STOPPED`, exit code 0 | none |
| this branch | `RUNNING` | 7023 "terminated with the following error" and 7031 "terminated unexpectedly ... restart the service", twice |

On this branch, the service also wrote the error to its `Duplicati 2` event log.

A wixl MSI built with these tables differs from the master one only in the 2 new rows and the ProductCode. Not verified: whether an installed MSI applies the recovery actions, and the path where the webserver fails after it has started.

Rebased on master [d6dcdd0c7](https://github.com/duplicati/duplicati/commit/d6dcdd0c734f99d9c5101e55cd3dc287b191e5e9): the solution builds, with no warnings in the changed files.

Refs #7740

🤖 Generated with [Claude Code](https://claude.com/claude-code)
