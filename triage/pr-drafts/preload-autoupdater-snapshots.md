## Summary

`MapExecutableName` has had the `autoupdater` and `snapshots` keys, but `Duplicati.Library.AutoUpdater.Program.Main` and `Duplicati.Library.Snapshots.Program.Main` never called `PreloadSettingsLoader.ConfigurePreloadSettings`, so `preload.json` had no effect on these tools. They now call it at the start of `Main`, like the other command line tools.

SharpAESCrypt is left as it is on purpose: it only takes positional arguments (`e|d <password> [<fromPath> [<toPath>]]`) and reads no options or environment variables. With an argument appended the way the preload settings do it, `SharpAESCrypt e pw --log-level=Warning < in > out` fails with `Input file not found: --log-level=Warning` (exit 2), so any `*` argument in `preload.json` would break its stdin/stdout use.

## Testing

Manual run with `DUPLICATI_PRELOAD_SETTINGS` pointing at a file with `"autoupdater": ["pk-from-autoupdater"]` and `"snapshots": ["--help"]` in `args`, and `DUPLICATI_PRELOAD_SETTINGS_DEBUG=1`:

- Before: `AutoUpdater help` prints the usage (exit 0) and neither tool prints any preload debug output.
- After: both print `Loaded preload settings from ...`; `AutoUpdater help` reports `Invalid number of arguments, got 2: help pk-from-autoupdater` (exit 100), and `Snapshots` with no command line arguments prints its usage because the preload settings supply `--help`.
- Build of the touched projects: 0 warnings.

There is no unit test: the keys already existed, and the preload file path is read into a static field when the type is loaded, so the call sites cannot be exercised in-process.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
