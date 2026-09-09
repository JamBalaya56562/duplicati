On Windows, ReleaseBuilder builds the MSI packages with the WiX toolset instead of wixl, but that path did not build: it only replaced the WiX 3 namespace in the sources, which are written for wixl in the WiX 3 format.

## The change

The Windows path now:

- copies the installer sources to a work folder, converts the copy with `wix convert` (new `WixV4Sources.cs`), and rewrites what wixl accepts but WiX rejects: nested `StandardDirectory` elements (`StartupFolder` in `ProgramMenuFolder`), the `MsiHiddenProperties` property (now `Hidden`/`HideTarget`), and the own `ExitDialog`, which has the name of a WixUI dialog;
- keeps the script custom actions in the 32-bit script host, as wixl builds do;
- defines `BuildEnv=Windows`, adds the WixUI extension, and passes the license text and bitmaps that the wixl copy of WixUI uses.

The sources get, inside the existing `BuildEnv=Windows` blocks, the WiX elements for what wixl builds get from `InstallTables.sql`:

- the core `PermissionEx` (the util one has no `Sddl`);
- copying and removing `preload.json`;
- the service recovery: `ServiceConfig FailureActionsWhen` and `ServiceConfigFailureActions` (restart 60 seconds after a failure, at most twice a day, also when the service stops with an error code);
- the `ResolveSource`, `MoveFiles` and `MsiConfigureServices` rows, with the same positions and conditions.

wixl does not see these blocks.

`WixHeatBuilder` wrote the child elements of the file list without a namespace (`xmlns=""`), which WiX rejects; they now use the namespace of the document. The README describes how to install WiX and the UI extension, and that WiX 7 needs its OSMF EULA accepted.

wixl builds are unchanged: a branch build and a master build from the same files have the same rows in every table, except the generated `ProductCode`.

## Testing

- A ReleaseBuilder run on Windows with WiX 6.0.2 (the CI options, `--targets win-x64-gui.msi --targets win-x64-agent.msi`) builds both MSIs. On this branch, read from the built MSIs, the rows that wixl builds get from `InstallTables.sql` are the same as the rows in `InstallTables.sql`, for both packages:
  - `MsiServiceConfig`: `5 | 3 | 1` (delayed start) and `5 | 4 | 1` (failure actions flag);
  - `MsiServiceConfigFailureActions`: `5 | 86400 | 1[~]1[~]0 | 60000[~]60000[~]0`;
  - `MsiLockPermissionsEx`, the `preload.json` `MoveFile` and `RemoveFile` rows, and `ResolveSource` 850, `MoveFiles` 3800, `MsiConfigureServices` 5850 in `InstallExecuteSequence`.
- The warnings are WIX1103 (the default file version for unversioned files), WIX5437, WIX1070/1071 and WIX1149, which WiX reports for the core `ServiceConfig` and `ServiceConfigFailureActions` elements. The same elements are what the wixl builds get as rows.
- Earlier, on the master of 2026-11-09, with WiX 4.0.6 and 6.0.2: all tables of both MSIs matched the wixl builds of the same files apart from short file names, row ids, the extra WixUI dialogs and `MigrateFeatureStates`, which wixl adds. Installed as an administrator: `preload.json` is copied and removed, the install folder gets the same ACL, the service is set to delayed start, a repair sets it again, and an uninstall removes everything. The Agent MSI was installed with `preload.json` pointing it at a local address, so it did not register with the console.
- `ReleaseBuilder.csproj` builds with no warnings.
- Not done after the rebase onto #7837: building the MSIs again. #7837 changes the conditions of a `Feature` and of two custom actions in `TrayIcon/Duplicati.wxs`, the same kinds of elements that already went through `wix convert` and the build above.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
