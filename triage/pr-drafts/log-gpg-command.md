The command that runs gpg was only printed to the console in debug builds, so a user could not see which gpg ran with which options (#1940).

## The change

- `GPGEncryption.Execute` logs the program and its arguments at the profiling level (`GPGCommand`), as the issue asks.
- The passphrase goes to the standard input of gpg, not its arguments. The switches (`--gpg-encryption-switches` and the others) may still carry one, so the value of a `--passphrase` switch is shown as `***`. `--passphrase-fd 0` is shown as it is.
- The `GPGExecuteError` message for a gpg that cannot start showed the arguments with such a value. It now hides it the same way.

## Testing

3 new tests in `GPGEncryptionTests`, failing on master and passing here:

- the command is logged
- a passphrase in the switches is not in the log
- a passphrase in the switches is not in the error when gpg cannot start

All 9 tests in `GPGEncryptionTests` pass. No new warnings in the changed files.

Fixes #1940

🤖 Generated with [Claude Code](https://claude.com/claude-code)
