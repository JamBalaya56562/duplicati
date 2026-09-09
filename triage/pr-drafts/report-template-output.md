## Summary
The `Template` result output format (`--send-*-result-output-format=Template`) never rendered the bundled Handlebars templates, and every value in the report header was empty. Running a backup with `--send-http-result-output-format=Template --send-http-message=%RESULT%` sent:

    Duplicati  Report
    ======================================
    Status:
    Backup Name:
    Machine:

Two separate causes:

1. **Embedded templates were never found.** The templates moved to `Duplicati.Library.ResultSerialization` in [`41408a1c`](https://github.com/duplicati/duplicati/commit/41408a1c12bc8a52f79c0d8f442b08549c4686e9), but `TemplateFormatSerializer` still looked them up with the old `Duplicati.Library.Modules.Builtin.Templates.` prefix. Every lookup fell through to the minimal built-in fallback template, and `GetAvailableTemplates()` returned nothing. The prefix now matches the actual manifest names (`Duplicati.Library.ResultSerialization.Templates.<name>.hbs`).
2. **No values were passed to the template.** `ReportHelper` called `Serialize(..., additional: null)` for non-JSON formats, so `OperationName`, `ParsedResult`, `BackupName`, `MachineName`, `MachineId` and `OperatingSystem` were always empty. `ReportHelper` now passes these under the PascalCase names that all bundled templates use (configured option first, then the default). `RemoteUrl` is deliberately not passed, since it can contain credentials.

## Testing
- New `TemplateReportModuleTests` runs a backup through the real `SendHttpMessage` module against a local `HttpListener` and checks the received body: the `default.hbs` layout, and the `Status`, `Backup` and `Machine` values. All three tests failed before the change. With only the first fix applied, the value test still failed.
- `TemplateReportModuleTests`, `TemplateSerializerTests`, `ReducedReportModuleTests`, `ReportHelperOperationsTests`, `ReducedReportFormatTests`: 57 passed.
- Manual: a CLI backup with `--send-http-result-output-format=Template` now delivers `Duplicati Backup Report` / `Status: Success` / `Backup: …` / `Machine: …`.

Related: #6280

🤖 Generated with [Claude Code](https://claude.com/claude-code)
