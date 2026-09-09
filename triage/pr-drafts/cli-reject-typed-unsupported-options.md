An option typed on the command line that Duplicati does not know, such as a misspelled one, only gives a warning, and the operation runs without it (#7123).

## The change

- The command line tool passes the names of the options typed on it to the controller (new `Controller.RejectUnsupportedOptions`). `ValidateOptions` then stops with the new error `UnsupportedOptionGiven` before the operation starts when one of them is not supported, or belongs to a module that is not loaded.
- Only the console entry point (`Program.Main`) stops. `RunCommandLine` has a new `rejectUnsupportedOptions` argument that is false by default, so the command line page of the web UI, which runs with the options of saved jobs, and the tests keep the warning.
- Options read from a parameters file, and the options of the command line tool itself (`Program.SupportedOptions` and their aliases), still only warn.

## Testing

New `CommandLineUnsupportedOptionTests`, 5 tests, all pass:

- a typed `--bla` exits with 100 and does not run
- an option of a disabled module exits with 100
- `--bla` in a parameters file exits with 2 and runs (warning only)
- `--quiet-console` does not stop the run
- without the switch it exits with 2 and runs, as before

The command line and option validation tests (11 classes, 116 tests) pass. The BulkData `CommandLineOperationsTests` (2 tests, through `Program.Main`) pass on their own. No new warnings in the changed files.

`--quiet-console` already gives an "unsupported option" warning from the controller on master, and a backup ends with exit code 2. I kept that for a separate PR.

Fixes #7123

🤖 Generated with [Claude Code](https://claude.com/claude-code)
