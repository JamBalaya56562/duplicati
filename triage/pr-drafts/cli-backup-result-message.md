Title: Do not report a stopped or failed CLI backup as successful

## Summary

The CLI `backup` command printed `Backup completed successfully!` for every backup that returned, whatever the result. It did so when a `--run-script-before` script stopped the backup (exit code 1, 3 or 5), and when the backup ended with errors. The exit code was already right (for example 3 after a script exit 5), so only the message was wrong.

The message now follows the result:

- The backup was stopped before it completed (by a script or a stop request): `Backup was stopped before it completed`
- The backup ended with errors: `Backup completed with errors`
- Otherwise: `Backup completed successfully!`, as before. Backups with warnings still get this message, so their output is unchanged.

Commit: [81857716b38c46318f55b3bacad53df5a9374df4](https://github.com/JamBalaya56562/duplicati/commit/81857716b38c46318f55b3bacad53df5a9374df4)

## Testing

- New `RunScriptTests.CommandLineBackupReportsTheResultOfTheScript` runs `backup` through `Duplicati.CommandLine.Program.RunCommandLine` with a `--run-script-before` script and checks the exit code and the final message:
  - script exit 0 → exit 0, `Backup completed successfully!`
  - script exit 1 → exit 1, `Backup was stopped before it completed`
  - script exit 4 → exit 3, `Backup completed with errors`
  - script exit 5 → exit 3, `Backup was stopped before it completed`
- On master, the exit 1, 4 and 5 cases fail: the exit codes match, but the output says `Backup completed successfully!`. With the change, all 4 pass.
- `dotnet test --filter FullyQualifiedName~RunScriptTests`: 28 passed, 0 failed.
- The build has no new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
