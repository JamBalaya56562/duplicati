Fixes #5212

## Summary

Scripts run by `--run-script-before` and `--run-script-after` only get `DUPLICATI__LOCALPATH`. In a restore that holds the paths being restored, so a script cannot tell which job sources the files came from.

- The server now passes the expanded sources of the job to every operation, in a new internal option `backup-sources`, joined with the path separator. It is set in `Runner`, not in `ApplyOptions`, because `ApplyOptions` also builds "export as command line", and the CLI refuses an internal option.
- The run-script module passes it to the script as `DUPLICATI__BACKUP_SOURCES`. A backup started outside the server (from the CLI) gets its local path instead. The name follows the existing `DUPLICATI__` convention (double underscore); the issue suggested `DUPLICATI_BACKUP_SOURCES`.
- Like `DUPLICATI__LOCALPATH`, the variable is left out with reduced reporting.
- The option is listed in `Options.InternalOptions`, so it is not reported as unsupported.
- `run-script-example.sh` and `run-script-example.bat` describe the new variable. The scripts page in duplicati/documentation (`detailed-descriptions/automation-and-integration/scripts.md`) embeds these examples and can be updated after this is merged.

## Testing

- `RunScriptTests.ScriptsSeeTheBackupSourcesAsync` runs real scripts on a CLI backup, and on a restore with the option set the way the server sets it. It checks the variable and that no warning is raised.
- `RunScriptTests.BackupSourcesAreLeftOutWithReducedReportingAsync`: the variable is empty with reduced reporting. This one also passes without the change.
- `ServerApiIntegrationTests.ScriptsSeeTheBackupSourcesOfTheJob_Async` runs and restores a job through the server API. The `run-script-after` script sees the job source in both operations.
- Without the change, the first and the third test fail. With it, all three pass.
- On the current master, all `RunScriptTests` and the new server test pass (35 of 35). The build adds no warnings. Run on Windows only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
