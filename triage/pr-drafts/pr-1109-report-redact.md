Paths in reports are redacted unless `--allow-paths-in-log-messages` is set. The redaction ran on the whole report after the template was expanded, which went wrong in two ways:

1. **HTTP reports were sent without redaction.** `SendHttpMessage` overrides `ReplaceTemplate`, keeps the expanded body itself and returns an empty string to `ReportHelper`, so the text that `ReportHelper` redacted was empty and the body that was sent was not redacted. A receiver got, for example, `message=Source: /home/someone/secret`, and a JSON report had the path in the error message as it was.
2. **The other modules redacted the template too.** A path that the user wrote in the template, such as a mail subject `Backup of /srv/data`, was replaced.

## The change

The redaction moved into `ReplaceTemplate`:

- With a template, each value put into it is redacted, in the subject and in the body.
- With the JSON format, which does not use the template, the whole result is redacted.
- The redaction of the whole report in `OnFinish` is removed.

`--allow-paths-in-log-messages` still keeps the paths.

## Testing

New tests in `ReportPathRedactionTests`:

| test | master | this branch |
|---|---|---|
| `APathPutIntoAnHttpReportIsRedactedAsync` | **fail**: the path was sent | pass |
| `APathInAJsonHttpReportIsRedactedAsync` | **fail**: the path was sent | pass |
| `APathWrittenInAMailTemplateIsKeptAsync` | **fail**: the written path was replaced | pass |
| `APathWrittenInTheTemplateIsKeptAsync` | pass | pass |
| `PathsAreKeptWhenAllowedAsync` | pass | pass |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `ReportPathRedactionTests`, 5 passed. Before the rebase, the 16 report test classes, 175 passed. No warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
