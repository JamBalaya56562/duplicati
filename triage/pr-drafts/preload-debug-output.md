Fixes #6308

## What happens

The issue reports that setting `DUPLICATI_PRELOAD_SETTINGS_DEBUG=1` made the tray icon print nothing to the console. Since [`7f6b212df91fd282d53e3e65ab4fccfc9ef05a5a`](https://github.com/duplicati/duplicati/commit/7f6b212df91fd282d53e3e65ab4fccfc9ef05a5a), `Utility.AttachWindowsConsole` sets new console writers after attaching, so that part is fixed. Two things from the issue and its comment remain on today's master:

- The tray icon reads the preload settings before it attaches to the console, because the settings can set `--detached-process`, which decides whether it attaches. The debug output of the preload loader is written then, so the tray icon never shows it, while `Duplicati.Server`, a console application, does.
- `DUPLICATI_PRELOAD_SETTINGS_DEBUG=0` turns the debug output on, as any value that is set does. The comment in the issue notes this too.

## The change

- `PreloadSettingsLoader` reads the variable with `Utility.ParseBool`: `0`, `false`, `off` and `no` turn the output off. Any other value that is set still turns it on, as before, so a value someone already uses keeps working.
- The tray icon keeps what the preload loader writes in a `StringWriter`, and writes it once the console is attached, or not, as decided as before. The order of reading the settings and attaching is unchanged.

## Checked

`PreloadSettingsDebugTests` (new) checks how the value is read: unset, empty, `0`, `false`, `off` and `no` turn the output off; `1`, `true`, `yes` and any other value turn it on.

The console behaviour was checked on Windows the way the issue does it: `--help` was run from a new `cmd.exe` console window, so the tray icon has no console until it attaches. What the window showed was then read back from its screen buffer.

| Run | Before | After |
|---|---|---|
| Tray icon, `=1` | help shown, **no preload output** | help shown, preload output shown |
| Tray icon, `=0` | help shown, no preload output | the same |
| Tray icon, unset | help shown, no preload output | the same |
| `Duplicati.Server`, `=1` | preload output shown | the same |
| `Duplicati.Server`, `=0` | **preload output shown** | no preload output |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
