# Use the local time zone for schedules when none is set

On [the forum](https://forum.duplicati.com/t/22834), all jobs started an hour early (01:00 → 00:00) once daylight saving ended on 2026-10-25.

74bb22e02 (for #1364) made schedules keep their time of day across daylight saving changes, in the time zone set with `server-timezone`. When that setting is empty, `ServerSettings.Timezone` returned UTC, so a daily schedule kept its UTC time instead, and moved by an hour in local time at each change.

The setting is empty on most installs:

- Nothing sets it on a new install or on startup. It is only written by the settings page of the old UI and by `--webservice-timezone`.
- ngclient has no setting for it.
- The settings page of the old UI shows the local time zone when it is empty, so it looks set.
- [The documentation](https://github.com/duplicati/documentation/blob/main/duplicati-programs/server.md#timezone) says "On the initial startup, the system timezone is detected and stored in the server database", but no code does that, now or in 74bb22e02.

With this change, an empty setting means the local time zone, which is what the old UI shows and what the documentation describes. A time zone that is stored but cannot be resolved already falls back to the local one. The scheduler is the only user of the setting.

A schedule that has been running an hour off since the last change goes back to the time it was set for at its next run.

## Testing

New `ServerTimezoneTests`:

- `AnUnsetTimezoneIsTheLocalOne`: a new server database. On master `Expected: <(UTC+09:00) ...> But was: <(UTC) ...>`; passes with the change.
- `ADailyScheduleKeepsItsLocalTimeWhenDaylightSavingEnds`: a daily schedule at 01:00 in Europe/Luxembourg that ran on 2026-10-25 at 01:00 summer time. With the Luxembourg time zone the next run is 2026-10-26 01:00; with UTC it is 2026-10-26 00:00, as reported. This passes before and after the change, and shows what the change does for a server in that time zone. It cannot be shown through `TimeZoneInfo.Local` here, as the test machine is in a time zone without daylight saving.

`ServerTimezoneTests`, `SchedulerTests`, `TimeZoneHelperTests` and `TimeSpanParserTests`: 25 passed on Windows. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
