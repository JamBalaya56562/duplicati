## Summary

`ReportHelper.ReplaceTemplate` expands a report template (`--send-mail-body`, `--send-http-message` and so on) one key at a time. Every later pass, and the final removal of unknown `%...%` keys, also ran over the values that earlier passes had put in. Two problems came from this:

- **A `%` in a value was treated as template text.** The result (`%RESULT%`) carries the log lines, and a file name like `percent-%backup-name%-50%-x%-end.txt` arrived as `percent-expanded-50-end.txt`: `%backup-name%` was expanded and `%-x%` was removed as an unknown key. Option values were affected the same way.
- **Option and extra parameter keys went into the regex unescaped.** A `send-http-extra-parameters` key like `a(b` threw `RegexParseException: Invalid pattern '%a(b%' at offset 5. Not enough )'s.`, and no report was sent (the error is only logged as `ReportSubmitError`). A key like `a.c` also matched `%abc%`.

Each key is now replaced by a marker without `%`, and the values are put in after the last pass, so nothing in a value is matched again. Keys are matched with `Regex.Escape`. The template text itself is expanded as before, including the order of the passes and the removal of unknown keys.

A value that itself contains a key (for example an extra parameter set to `%backup-name%`) is now sent as written; before, it was expanded or removed depending on the order of the passes.

Commit: [85759099db97dfc959f0d82cb6a603e5840067a7](https://github.com/JamBalaya56562/duplicati/commit/85759099db97dfc959f0d82cb6a603e5840067a7)

I could not find an issue for this.

## Testing

Two new tests in `ReportTemplateDollarTests`, which run a backup that sends its report to a local HTTP receiver:

| test | before | after |
|---|---|---|
| `ResultKeepsPercentSequences` (file `percent-%backup-name%-50%-x%-end.txt`, `backup-name=expanded`) | **fail**: the body has `percent-expanded-50-end.txt` | pass |
| `TemplateKeysWithRegexCharactersMatchLiterally` (extra parameters `a(b` and `a.c`, message `paren=[%a(b%] dot=[%a.c%] other=[%abc%]`) | **fail**: no report, `RegexParseException` | pass: `paren=[paren] dot=[dot] other=[]` |

The other report tests pass: `ReportTemplateDollarTests`, `ReportHelperOperationsTests`, `ReportResultLogTests`, `ReducedReportModuleTests`, `TemplateReportModuleTests`, `HttpReportStatusTests`, `SendHttpMessageTargetsTests`, `ModuleOptionTypeTests`, `XmppRecipientsTests`, `XmppTargetTests` (77 in all). The build has no new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
