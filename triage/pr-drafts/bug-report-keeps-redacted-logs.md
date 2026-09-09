Title: Keep the logs in a bug report with their paths redacted

A bug report replaced every stored log message and exception that contained a `/` or `:\` with `ERASED!` (`LocalBugReportDatabase.ObfuscateAsync`). The result of an operation is stored as JSON with its log lines, and nearly every one has a path or a slash, so the logs of the latest operations were not in the report (#3491).

## The change

- The paths are redacted instead of the whole value, with the same path detection as the reports (`SensitiveDataFilter.RedactPaths`).
- A JSON result is redacted value by value. Dates and numbers are kept.
- A bug report may be shared in public, so this is stricter than in a report:
  - A path can have spaces, so the rest of the line after a path is redacted too.
  - A word with a path separator that is not found as a path, such as a relative path or a URL, is redacted together with the words before it, back to a word that ends with a colon, and the rest of the line.

## Testing

- `VacuumAndBugReportTests`, 14 tests on Windows and Linux.
  - The new `BugReportKeepsTheLogsWithoutPathsAsync` makes a warning about a missing source with spaces in its path, creates the report and opens its database. The warning is there with `-redacted-`, and none of the values contains the folder or file names.
  - Without the change it fails, because every result row is `ERASED!`.
  - 9 more tests of `RedactLogText`: no path, paths with spaces on Windows and Unix, a relative path, a URL, two spaces in a path, and stack trace lines.
- A report with 1004 results (73.5 MB of text, 300 warnings with a path with spaces on one line) takes about 9 s instead of 4 s. The zip grows from 0.0 MB to 1.5 MB, as the logs are now kept. None of its 350,000 values contained the folder names.

Not tried: macOS.

Fixes #3491

🤖 Generated with [Claude Code](https://claude.com/claude-code)
