`ReportHelper.ReplaceTemplate` passed the serialized result (`%RESULT%`) and every `%key%` value as the *replacement string* of `Regex.Replace`. .NET reads `$&`, `$1`, `$$`, `` $` ``, `$'` and `$_` in a replacement string as substitutions, so a file name, option value or extra parameter containing one of them corrupted the report body. `$_` even copies the whole template into it: a 223-character body grew to 64,903 characters in the test.

This affects the Duplicati and Template result formats (the default `%RESULT%` body, through the log lines), custom message templates using `%backup-name%`, `%localpath%`, extra parameters and other keys, and the subject line. The Json format does not go through these replacements and was not affected.

The fix passes each value through a `MatchEvaluator` (`_ => value`), so it is inserted as-is. The result is still serialized once.

### Tests
`ReportTemplateDollarTests` runs a real backup that reports to a local `HttpListener`, with `$&-$1-$$-$`-$'-$_` in the source folder name, file name, backup name and an extra parameter, and checks the received body:
- Duplicati format (default body): the logged file path arrives intact (failed before the fix)
- Template format: same (failed before the fix)
- Custom template with `%backup-name%`, an extra parameter and `%localpath%` (failed before the fix)
- Json format: unaffected (passed before and after)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
