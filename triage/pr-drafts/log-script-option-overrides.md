Fixes #3447

## Summary

A `--run-script-before` script can change options, the remote URL and the source paths by printing `--key=value` lines, but nothing recorded what it changed. The controller now compares the options, the remote URL and the source paths before and after the run-script module's `OnStart`, and writes Information messages for the changes:

- `ScriptChangedOptions`: the names of the changed options, for example `The script run before the operation set the options --backup-name, --passphrase`
- `ScriptChangedRemoteUrl`: the new remote URL, without credentials (`Utility.GetUrlWithoutCredentials`)
- `ScriptChangedLocalPath`: the new source paths

Option values are never logged. A common reason for such a script is to fetch secrets from a vault, and not every secret is declared as a password option: `--send-telegram-api-key` is a string option, for example, and other options can hold URLs with tokens. The log ends up in the database and in reports, so logging the values could leak secrets.

Already implemented before this PR (the other parts of the issue and its comments):

- stdout lines starting with `LOG:INFO`, `LOG:WARN` or `LOG:ERROR` go to the log: [671c88eeff0fe197e8e47aa172995181151aa5a1](https://github.com/duplicati/duplicati/commit/671c88eeff0fe197e8e47aa172995181151aa5a1)
- the operation status shows a RunScript phase while a script runs: [e08c36851c11a77bae3583d6972eccb921f77f63](https://github.com/duplicati/duplicati/commit/e08c36851c11a77bae3583d6972eccb921f77f63)
- stderr output is logged as a warning (`StdErrorNotEmpty`)

## Testing

- New `RunScriptTests.ScriptOptionChangesAreLoggedAsync`. The script sets `--backup-name`, `--passphrase`, `--send-telegram-api-key`, `--remoteurl` and `--localpath`. The test checks that the option names and the URL and path messages are logged, and that none of the values appears in any message. It fails without the change and passes with it.
- On the current master, all `RunScriptTests` pass (33 of 33). The build adds no warnings. Run on Windows only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
