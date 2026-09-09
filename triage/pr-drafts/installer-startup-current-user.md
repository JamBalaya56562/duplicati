Title: Let the installer start Duplicati at logon for the current user only

The installer runs per machine, so the startup shortcut goes into the Startup folder shared by every user, and Duplicati starts for everyone who logs on (#4786).

## The change

- A new checkbox in the installer options, "Only for the current user, not for every user of this computer", or `STARTUP_FOR_CURRENT_USER=1` on the msiexec command line.
- When it is set, the new feature `DuplicatiUserStartupShortCutFeature` writes a `Run` entry in HKCU instead of the shared startup shortcut, so Duplicati starts only for the user who installs it. The entry gets `--no-hosted-server` when the service is installed, like the shortcut.
- The default is unchanged.
- A marker value in HKCU lets an upgrade with the installer UI keep the choice. Like the install location, a silent upgrade has to pass the property again, as the previous version's values are read after it has been removed.

## Testing

The MSI was built with this change and installed on Windows 11:
- `/qn STARTUP_FOR_CURRENT_USER=1`: a HKCU `Run` entry for `Duplicati.GUI.TrayIcon.exe` and the marker, no shared shortcut. The log shows the new feature installed and the shared one not. Uninstalling removes both.
- Default: only the shared shortcut, no `Run` entry. Uninstalling removes it.
- Upgrade from an MSI built as an older version: with the UI (`/qr`) the choice is kept. With `/qn` it is not (expected, as above). An upgrade from the current default keeps the shared shortcut.

Fixes #4786

🤖 Generated with [Claude Code](https://claude.com/claude-code)
