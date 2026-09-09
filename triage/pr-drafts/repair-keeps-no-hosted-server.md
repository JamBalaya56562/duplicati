Title: Keep --no-hosted-server on the shortcuts when the installer repairs

## What happens

With Duplicati installed as a Windows service, the Start menu, Startup and Desktop shortcuts start the tray icon with `--no-hosted-server`, so it connects to the service. A repair with the MSI recreates the shortcuts without the flag. The tray icon then starts its own server instead of connecting to the service. This is one of the problems in #7804 ("Repair ... the TrayIcon stays on HTTP").

The flag comes from `NOHOSTEDSERVERARG`, which `SetNoHostedServerArg` sets when `&DuplicatiServiceFeature=3`. In a repair the feature's action is Reinstall, not 3, so `ClearNoHostedServerArg` runs instead, and `CreateShortcuts` (REINSTALLMODE includes `s`) writes the shortcuts with no arguments.

## The change

The two conditions now check whether the service feature is installed after the run: either it is being installed (`&DuplicatiServiceFeature=3`), or it is installed and not being removed (`!DuplicatiServiceFeature=3 AND NOT &DuplicatiServiceFeature=2`). The comment in `Shortcuts.wxs` says the same.

The current-user startup entry in HKCU `Run` (#7811) is built from the same property, so a repair dropped the flag there too, and this change keeps it. I did not test that entry, as the MSI I tested is 2.4.1.0, which does not have it.

## Testing

On Windows 11, with the official 2.4.1.0 MSI and a copy of it where only these two conditions were changed (the same text as this change, set with `msilib`). For each: install with the service (`/qn ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature,` and the three shortcut features), repair (`REINSTALL=ALL REINSTALLMODE=ecmus`), and uninstall.

| | After install | After repair |
|---|---|---|
| Official MSI | `--no-hosted-server` on all 3 shortcuts | no arguments on all 3 |
| With the change | `--no-hosted-server` on all 3 shortcuts | `--no-hosted-server` on all 3 |

The repair log shows `ClearNoHostedServerArg` running with the official MSI, and `SetNoHostedServerArg` with the change. The same loss happened with a repair from the installer UI (three runs with the official MSI).

I did not build the MSI from this branch.

Refs #7804

🤖 Generated with [Claude Code](https://claude.com/claude-code)
