## Summary

- SyncTool (`Tools/RemoteSynchronization`) and AutoTuneTool (`Tools/AutoTune`) never called `PreloadSettingsLoader.ConfigurePreloadSettings`, so `preload.json` had no effect on them, not even the `*` section. They now call it with their own `NamedExecutable` at the start of `MainAsync`, like the other command line tools.
- `MapExecutableName` had no entry for them; they now map to `synctool` and `autotunetool`.

## Testing

- New `PreloadSettingsSyncAndAutoTuneKeyTests` (`MapExecutableName` made `internal` for it): without the new map entries both cases fail with `But was: "*"`; with them they pass.
- `--filter "FullyQualifiedName~PreloadSettings|FullyQualifiedName~ToolTests.TestMainMethodParsesArgumentsCorrectly|FullyQualifiedName~ToolTests.TestDryRunAsync"`: 15/15 pass (the two `ToolTests` go through `RemoteSynchronization.Program.MainAsync`).
- Manual run with `DUPLICATI_PRELOAD_SETTINGS` pointing at a file with `--pk-from-star=1` in `*`, `--pk-from-synctool=1` in `synctool` and `--pk-from-autotunetool=1` in `autotunetool`, plus `--pk-cmdline=1` on the command line so neither tool does any work:
  - Before: both tools only report `--pk-cmdline=1` as unrecognized and print no preload debug output.
  - After: SyncTool also reports `--pk-from-star=1` and `--pk-from-synctool=1`, AutoTuneTool `--pk-from-star=1` and `--pk-from-autotunetool=1`; no unknown-key line.
- Build of the touched projects: 0 warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
