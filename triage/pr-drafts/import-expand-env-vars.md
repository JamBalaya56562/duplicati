Fixes #6391

An exported configuration can now be used as a template. With `expand_env_vars` on `POST /api/v1/backups/import`, or `--expand-env-vars` with `duplicati-server-util import`, `%VAR%` environment variables in the configuration are expanded with the values of the server:

- the name and description
- the target URL and the additional target URLs
- the sources
- the option values
- the filter expressions

Today only sources, filters and the restore path are expanded, and only when a job runs. So a template could not hold a machine-specific target URL, name or option value.

- Only the `%VAR%` syntax is expanded, on every platform. `$VAR` is left alone, so a `$` in a password or a URL is not changed.
- A variable that is not defined is left as it is.
- Values given to `replace_settings` (`--backup-url`, `--backup-passphrase`) are used as they are, not expanded.
- Without the flag, nothing changes.

The checkbox in the import page of ngclient is not part of this PR.

## Testing

- New `ServerApiIntegrationTests.ImportExpandsEnvironmentVariablesWhenAsked_Async(true/false)`: a configuration exported and edited to hold a variable in each of those fields, imported through the HTTP endpoint as plain JSON. On master, the `true` case fails because nothing is expanded (`Template %DUPLICATI_TEST_IMPORT_...%`); with the change, both cases pass, and an undefined variable stays as it is.
- The existing import tests (`ImportSupportsProvidingPassphraseOverride_Async`, `ImportExportTests`) pass: 6 passed in total.
- `Duplicati.slnx` builds with no new warnings in the changed files. `duplicati-server-util import --help` lists the new option.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
