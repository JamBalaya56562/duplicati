# Do not let the preload check crash the service installer

Fixes #7476

The event log in #7476 shows why the update failed:

```
Duplicati.WindowsService.exe ... The process was terminated due to an unhandled exception.
Duplicati.Library.Interface.UserInformationException: The directory 'C:\Users\Duplicati\AppData\Local\Duplicati' holding the preload settings file '...\preload.json' is not securely protected (an unexpected access rule grants rights to S-1-5-21-...-1003). ...
   at Duplicati.Library.AutoUpdater.PreloadSettingsLoader.VerifyPreloadFileSecurity(String path)
   ...
   at Duplicati.WindowsService.Program.Main(String[] args)
```

`Duplicati.WindowsService.exe` loads the preload settings before anything else, outside of any error handling, so a preload file in a folder that is not locked down to the current user crashes every command with 0xE0434352, `help` included. The installer runs `set-init-password` as SYSTEM, without `--server-datafolder`; on that machine the data folder (most likely set with `DUPLICATI_HOME`) is locked down to the account `Duplicati`, so the check refused it, the custom action failed, and the installer rolled back and left Duplicati uninstalled.

The check itself is right and stays as it is: a process running as SYSTEM must not load settings from a folder that a normal account can change.

With this change:

- `set-init-password`, `lock-service-key` and `secure-datafolder` only change the registry or the service, and `help` only prints, so they no longer load the preload settings. The installer step works, and `secure-datafolder`, which is the way to fix such a folder, is no longer stopped by the check it is meant to fix.
- The other commands (`install`, `uninstall`, `install-certs`, ...) still load the preload settings, as `install` passes them on to the service. When the check refuses the folder, they print the reason and exit with 1 instead of crashing.
- The service itself, started without a command, still stops with the exception, which Windows records in the event log. That is where the reason was found in #7476.

The reporter's service will still refuse the folder when it starts as SYSTEM, until the folder is locked down (`secure-datafolder`) or `--allow-insecure-datafolder` is set. This change makes the update itself complete and the reason visible.

## Testing

Run on Windows with the built `Duplicati.WindowsService.exe`, with `DUPLICATI_HOME` set to a folder holding a `preload.json` that the Users group can modify, `DUPLICATI__PORTABLE_MODE=false`, and `DUPLICATI__ALLOW_INSECURE_DATAFOLDER=false` (Debug builds allow an insecure folder unless told otherwise):

| command | master | with the change |
|---|---|---|
| `help` | crash, exit -532462766 (0xE0434352) | help text, exit 0 |
| `set-init-password` (no password given) | crash, exit -532462766 | `Refusing to set init password: DUPLICATI__INIT_PASSWORD environment variable is not set.`, exit 1 |
| `install-certs` | crash, exit -532462766 | the reason the folder was refused, exit 1 |
| no command (service) | crash, exit -532462766 | crash, exit -532462766 (unchanged) |

The exit code on master is the one in the MSI log of #7476. The registry-writing paths were not run, as they need an elevated process. There is no unit test: the preload paths are fixed when the loader is first used in a process, so a test in the unit test process cannot point them at its own folder.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
