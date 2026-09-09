## Summary

`AUTOUPDATER_Duplicati_SKIP_UPDATE` is read into `UpdaterManager.DISABLE_UPDATE_CHECK`, and the AutoUpdater help says it "Disables updates completely", but nothing has used the value since the updater rewrite in [115e8878029e9f0bba364cc49fd764a716d387e8](https://github.com/duplicati/duplicati/commit/115e8878029e9f0bba364cc49fd764a716d387e8). Before that it was `DISABLE_UPDATE_DOMAIN` and only skipped launching an installed update; the rewrite removed that mechanism and left the variable unused. So with the variable set, the server poller, the "check now" button, the CLI `--auto-update` and `duplicati-autoupdater check`/`download` all still contact the update server.

- `UpdaterManager.CheckForUpdate` returns `null` without sending a request when the variable is set. Every update path goes through it.
- `duplicati-autoupdater check`/`download` print that checks are disabled by the variable instead of "No updates found".
- An attached debugger no longer counts as disabling checks (the old `Debugger.IsAttached` term made sense for the update domain, not for checks).

`--disable-update-check` is unchanged: it still stops only the automatic poll and allows a manual check. The variable stops all checks, which is what the help text describes.

Related to #3983 (closed by [abe79b1a15b5142922f7bb77e80399b1704bcc01](https://github.com/duplicati/duplicati/commit/abe79b1a15b5142922f7bb77e80399b1704bcc01), which added `--disable-update-check`).

## Testing

No existing test reaches `CheckForUpdate`. The variable and the update URLs are read once per process, so an in-process NUnit test cannot redirect them reliably without risking a request to the real update server. Instead, a small console app referencing `Duplicati.Library.AutoUpdater` ran a local `HttpListener` as the update server (`AUTOUPDATER_Duplicati_URLS=http://127.0.0.1:18765/stable/latest.manifest`) and counted the requests:

| `AUTOUPDATER_Duplicati_SKIP_UPDATE` | before | after |
|---|---|---|
| unset | 1 request | 1 request |
| `true` | 1 request | 0 requests |
| `1` | – | 0 requests |
| `false` | – | 1 request |

`duplicati-autoupdater check` and `download` (through `AutoUpdater.Program.Main`) with the variable set print `Update checks are disabled by the environment variable AUTOUPDATER_Duplicati_SKIP_UPDATE` and send 0 requests; unset, `check` sends 1 request as before.

Build of `Duplicati.Library.AutoUpdater`: 0 warnings, 0 errors.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
