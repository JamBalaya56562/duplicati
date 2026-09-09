The mail report is always sent as `text/plain`, so HTML written in `--send-mail-body` shows as code (#7024).

## The change

The new `--send-mail-body-html` option (default false) sends the body as `text/html`.

- The values put into an HTML body, such as `%RESULT%`, the log lines and the options, are HTML-escaped after their paths are redacted. A file name in the log cannot add markup to the message.
- With `--reduced-reporting`, the text of the template is redacted too, since [90c2ed02e](https://github.com/duplicati/duplicati/commit/90c2ed02ef3ed95afdefc5fcdae7676788d72e01). In an HTML body, only the text between the tags is redacted: the whole body would turn `<p>Backup</p><pre>` into `<p>Backup<-redacted-`, as the slashes of the closing tags are taken for paths. The values are escaped, so every tag left in the body is from the template.
- The subject and plain text bodies are unchanged.

## Testing

New `SendMailHtmlBodyTests`, against a local SMTP server, with the body `<p>%OPERATIONNAME%</p><pre>%RESULT%</pre>`:

| test | without the change | this branch |
|---|---|---|
| `TheBodyIsPlainTextByDefaultAsync` | pass | pass |
| `TheBodyIsSentAsHtmlWhenAskedForAsync` | **fail** | pass |
| `TheValuesInAnHtmlBodyAreEscapedAsync` | **fail** | pass |
| `TheTagsOfAnHtmlBodyAreKeptAsync` | **fail** | pass |
| `TheTagsOfAnHtmlBodyAreKeptWithReducedReportingAsync` | **fail**: `<p>Backup<-redacted-` (with the option, before the reduced report change of this branch) | pass |
| `PathsInTheTextOfAnHtmlBodyAreRedactedWithReducedReportingAsync` | — | pass |
| `PathsInTheValuesOfAnHtmlBodyAreStillRedactedAsync` | pass | pass |
| `TheSubjectIsNotEscapedAsync` | pass | pass |

The first column was measured on master when the branch was written, except for the reduced report row.

Rebased on master [d6dcdd0c7](https://github.com/duplicati/duplicati/commit/d6dcdd0c734f99d9c5101e55cd3dc287b191e5e9), on Windows: `SendMailHtmlBodyTests` and `ReportPathRedactionTests`, 17 passed. No warnings in the changed files.

Fixes #7024

🤖 Generated with [Claude Code](https://claude.com/claude-code)
