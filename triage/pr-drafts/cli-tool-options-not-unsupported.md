Title: Stop reporting the command line tool's own options as unsupported

A backup from the command line tool with `--quiet-console` logs that the option is not supported, and ends with exit code 2 (warnings). The command line tool reads `quiet-console` from the same options it gives the controller, so the option reaches the controller, which does not know it.

## The change

The command line tool tells the controller which options it handles itself, with the new `Controller.OptionsHandledByCaller`. These are the names and aliases of `Program.SupportedOptions`. The controller adds them to the known options after the declared ones (`TryAdd`, so names it already knows, such as `control-files`, are not reported twice). The part of #7796 that subtracted the tool's options from the typed ones is no longer needed and is removed.

Removing the option from the dictionary was not an option: `ConsoleOutput` is public and also used by the tray icon and the tests, and the web UI runs command line operations in the same process.

## Testing

`CommandLineUnsupportedOptionTests`, 7 tests: `TheOptionsOfTheCommandLineToolAreAccepted` now requires exit code 0, with and without stopping on unsupported options. The new `ABackupWithKnownOptionsHasNoWarnings` is the control case. Before the change, the two cases failed with exit code 2. All 7 pass, with no new warnings in Main and the command line tool.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
