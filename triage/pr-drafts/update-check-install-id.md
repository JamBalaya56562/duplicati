## Summary

`UpdaterManager.CheckForUpdate` and `DownloadUpdate` already handle a missing install ID (an empty ID is left out of the user agent and sent as an empty `X-Install-ID`), but they read it with `DataFolderManager.GetInstallID()` instead of `GetInstallID(probeOnly: true)`. In a debug build that throws when `installation.txt` has not been created yet, which is the normal state for tools that do not initialize the data folder, such as `duplicati-autoupdater check` on a machine where the server has never run. The exception is passed to `OnError` and no request is sent.

Both reads now use `probeOnly: true`. Release builds already returned an empty ID here, so their behaviour does not change.

## Testing

No existing test reaches these methods. A small console app referencing `Duplicati.Library.AutoUpdater` (Debug build) ran a local `HttpListener` as the update server (`AUTOUPDATER_Duplicati_URLS=http://127.0.0.1:18765/stable/latest.manifest`):

| data folder | before | after |
|---|---|---|
| no `installation.txt` | `InvalidOperationException: The ID file "installation.txt" ... requested before the data folder was initialized`, 0 requests | 1 request, `X-Install-ID` empty |
| `installation.txt` = `probe-install-id` | – | 1 request, `X-Install-ID: probe-install-id` |

`duplicati-autoupdater check` (through `AutoUpdater.Program.Main`) with no ID file: 1 request and "No updates found" after the fix.

Build of `Duplicati.Library.AutoUpdater`: 0 warnings, 0 errors.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
