## Summary

The `--vss-provider-id` description, added in [2920705699fc7f78ccb6170385f31064891e0f8f](https://github.com/duplicati/duplicati/commit/2920705699fc7f78ccb6170385f31064891e0f8f), contains the GUID `{b5946137-7b9f-4925-af80-51abd60b20d5}` in single braces. The commandline help forces the invariant culture, and with that culture `LC.L` runs the text through `string.Format`. On Windows, any help topic that builds the option list therefore threw instead of printing. That includes `help backends`, `help vss-provider-id` and unknown topics:

```
System.FormatException: Input string was not in a correct format. Failure to parse near offset 404. Expected an ASCII digit.
   at Duplicati.Library.Localization.MockLocalizationService.Localize(String message)
   at Duplicati.Library.Main.Strings.Options.get_VssprovideridLong()
   at Duplicati.Library.Main.Options.GetOSConditionalCommands()+MoveNext()
```

The GUID is now passed as a format argument (`... GUID {0} to force ...`). Doubling the braces is not enough. Other cultures (for example en-US in the server and the web UI) use `MoLocalizationService`, which does not format a string that has no arguments, so they would show `{{b5946137-...}}`.

No translation contains this string yet, so changing the msgid does not drop existing translations.

## Testing

`OptionDescriptionFormatTests.VssProviderIdDescriptionShowsTheGuidInBraces` reads the description through `Options.SupportedCommands`, once with the invariant culture and once with en-US. The test is ignored outside Windows, where the option is not offered. Results on Windows:

| Description text | invariant | en-US |
|---|---|---|
| master (single braces) | fails, `FormatException` | passes |
| doubled braces `{{...}}` | passes | fails, shows `{{b5946137-...}}` |
| this PR (`{0}` + argument) | passes | passes |

With this change, `Duplicati.CommandLine.exe help backends` prints `Topic not found: backends`, and `help vss-provider-id` shows the GUID in single braces. No new build warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
