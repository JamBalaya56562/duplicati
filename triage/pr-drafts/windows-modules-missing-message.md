## What happens

The Windows-only modules (suspend and resume notifications, VSS helpers, toast notifications) are loaded at run time from `Duplicati.Library.WindowsModules.dll`, next to the program. The packages place it there: the release build publishes `Duplicati.WindowsModulesLoader` into every Windows package and checks that the file is present. The build output of a single project, such as `Executables/Duplicati.Server`, does not have it, as the project targets `net10.0` and cannot reference the Windows-only module.

Running such an output logs, while the server starts:

```
Failed to set up the power mode provider, suspend and resume events will not be handled: Failed to load Windows Component PowerManagementModule: Dependency resolution failed for component ...\Duplicati.Library.WindowsModules.dll with error code -2147450734. Detailed error: Failed to locate managed application [...\Duplicati.Library.WindowsModules.dll]
```

It says nothing about the file being absent. The warning appeared several times (4 times in one run), because `LiveControls.UpdatePowerModeProvider` records the chosen provider only after it has loaded, so each settings update tries, and reports, it again.

## The change

- `WindowsShimLoader` checks that the file exists before loading it, and otherwise throws `FileNotFoundException`: "Duplicati.Library.WindowsModules.dll was not found next to the program, in ...".
- `UpdatePowerModeProvider` records the chosen provider before loading it, so a provider that cannot be loaded is reported once, and tried again only when the setting changes.

The packages are not affected: the file is there, and loading works as before.

## Checked

With `Duplicati.Server` published in Release (win-x64), started with `--log-level=Information`:

| | Before | After |
|---|---|---|
| Server published on its own | **4 warnings**, "Failed to locate managed application" | 1 warning, "Duplicati.Library.WindowsModules.dll was not found next to the program, in ..." |
| Server with the `WindowsModulesLoader` output copied in, as the packages do | no warning | no warning |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
