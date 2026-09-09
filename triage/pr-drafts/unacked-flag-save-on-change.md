Registering or dismissing a notification sets `UnackedWarning` and `UnackedError`. Each set goes through `SetAndSaveSetting`, which rewrites every server setting (`DELETE` + `INSERT` of all rows) and calls `SignalSettingsChanged` (`IncrementLastDataUpdateId`, `SignalServerSettingsUpdated`, throttle refresh, `UpdatePowerModeProvider`, usage reporter). This happens even when the flag keeps its value, which is the common case: registering a warning while one is already pending, or dismissing one of several.

This PR skips the save and the signals when the flag does not change. When it does change, nothing is different.

The check is limited to these two flags. They are the only settings written on every notification; the other setters run at startup, on user actions, from remote control, or once per update check (weekly by default), so there is no performance reason to change them here.

Measured with 200 pending notifications, 200 register/dismiss rounds where the flags keep their value. The master and patched builds were run alternately, in rotating order, on a lightly loaded machine (13–37% CPU):

| per notification | master | this PR |
|---|---|---|
| register | 7.7–9.6 ms | 4.7–6.5 ms |
| dismiss | 10.7–13.1 ms | 4.4–6.2 ms |
| settings saves in 400 operations | 600 | 0 |

One settings save costs about 3–4 ms. When a flag does change, the cost is the same as before (register with a flip: 8.0–8.8 ms patched, 8.6–9.3 ms master).

Tests: `UnackedFlagSettingTests` checks that a same-value set leaves the database (`PRAGMA data_version` seen from a second connection), `LastDataUpdateId` and `ServerSettingsUpdate` untouched, that a change is still saved and signalled once, and that registering and dismissing notifications only signals when a flag flips.

Related to #4719

🤖 Generated with [Claude Code](https://claude.com/claude-code)
