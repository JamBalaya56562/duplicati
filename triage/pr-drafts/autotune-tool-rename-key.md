`ExecutableRenames` in ReleaseBuilder keyed the AutoTune tool as `Duplicati.CommandLine.AutoTuneTool.exe`, while every other entry has no extension. On Linux/macOS the build output has no `.exe`, so the key never matched. In the 2.4.0.1 linux-x64 cli `.zip` and `.deb`, the tool ships as `Duplicati.CommandLine.AutoTuneTool` with mode 644 and no `/usr/bin` link, while `PackageHelper` expects `duplicati-autotune-tool`.

This drops the `.exe` from the key, so the tool is renamed, marked executable and linked like the other tools. Windows packages are unaffected (renames apply only to non-Windows targets).

The table entry was added in https://github.com/duplicati/duplicati/commit/6367e8bf5612b3e66039f93cafea66ac407441fb (#6925).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
