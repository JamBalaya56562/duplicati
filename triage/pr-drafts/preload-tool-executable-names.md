## Summary

- `DatabaseTool` and `SourceTool` called `ConfigurePreloadSettings` with `NamedExecutable.ServerUtil`, so they loaded the `serverutil` section of `preload.json`. Arguments meant for ServerUtil were appended to their command lines; for example `--hosturl=...` was read as the database path by `DatabaseTool list` and as the source by `SourceTool list`. They now pass their own executable.
- `MapExecutableName` had no entry for `SecretTool`, `SourceTool` or `DatabaseTool`, so they fell back to `*` and could not have a section of their own (the debug output reported the keys as unknown). They now map to `secrettool`, `sourcetool` and `databasetool`.

## Testing

- New `PreloadSettingsExecutableNameTests` (`MapExecutableName` made `internal` for it): on master the `SecretTool`, `SourceTool` and `DatabaseTool` cases fail with `But was: "*"` (3 failed, 12 passed in `~PreloadSettings`); with the change 15/15 pass.
- Manual run with `DUPLICATI_PRELOAD_SETTINGS` pointing at a file with a distinct argument in the `serverutil`, `databasetool`, `sourcetool` and `secrettool` sections, and `DUPLICATI_PRELOAD_SETTINGS_DEBUG=1`:
  - Before: `Found unknown executable name(s) in args preload settings: databasetool, sourcetool, secrettool`; `DatabaseTool list` → `Database --hosturl=http://from-serverutil-section:1 does not exist`; `SourceTool list` → `The source "--hosturl=http://from-serverutil-section:1" is not supported`; `SecretTool info` ignored its section.
  - After: no unknown-key line; `DatabaseTool list` → `Database --pk-from-databasetool=1 does not exist`; `SourceTool list` reports the `--pk-from-sourcetool=1` folder; `SecretTool info` → `No secret provider found for key --pk-from-secrettool=1`. The ServerUtil argument no longer reaches either tool.
- Build of the touched projects: 0 warnings.

Note: anyone who relied on the `serverutil` section configuring DatabaseTool or SourceTool needs to move those settings to `databasetool` / `sourcetool`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
