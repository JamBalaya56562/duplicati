# Exit with the error code when a restore could not restore some files

When a restore cannot restore a file, for example because it cannot be created or because a block of it cannot be read, it reports the file as an error (`RestoreFailures`) and carries on with the others. The `restore` command of the CLI only mapped warnings to an exit code, so it then exited with 0, the code for success. A script could not tell that the restore was incomplete.

The command now exits with 3 when the result has errors. A backup that finished with errors also exits with 3. The exit codes in `help statuscodes` now list it.

## Testing

- New `RestoreExitCodeTests`, through `Program.RunCommandLine`:
  - `ARestoreThatCouldNotRestoreAFileExitsWithTheErrorCodeAsync`: a folder is in the way of one of two files. Master exits with 0 (red); with the change the exit code is 3, and the other file is restored.
  - `ARestoreOfEveryFileExitsWithSuccessAsync`: still 0.
- `RestorePathWithoutValueTests`, `RestoreTestHandlerTests`, `Issue4812`, `RunScriptTests`, `RestoreFileFailureTests`: 62 passed, including the new ones.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
