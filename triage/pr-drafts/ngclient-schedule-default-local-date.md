## Summary

The schedule defaults (the field defaults, every predefined option, and the fallback in `updateScheduleType`) built the date with `new Date().toISOString().split('T')[0]`, which is the **UTC** day. East of UTC that is the previous day for part of the morning — e.g. in Tokyo (UTC+9) between 00:00 and 09:00 a new backup's "Next time" defaults to yesterday. The "Weekly monday 13:00" option had the same problem for zones of UTC+12 or more, where 12:00 on the next Monday is still Sunday in UTC.

The save path already reads `YYYY-MM-DD` as a local day (`getLocalDateParts` → `new Date(year, month, day, …)`), so with this change the default that is displayed and the default that is saved are the same local day.

- Add `toLocalDateString(date)` that formats the local calendar day as `YYYY-MM-DD`, and use it for every default date in `schedule-v2/schedule.component.ts`.
- Use the same helper in the legacy `schedule/schedule.component.ts` (no route uses it now, but it had the same expression).

This is about the defaults for a new schedule, not the load path tracked in duplicati/ngclient#492.

Commit: [23362ab605b72737e19663e6287157fd0b77661f](https://github.com/JamBalaya56562/ngclient/commit/23362ab605b72737e19663e6287157fd0b77661f)

## Testing

Added `default schedule date` tests to `schedule-v2/schedule.spec.ts`. They stub `TZ` and freeze the clock at 2026-10-10T23:00Z (= 2026-10-11 08:00 in Tokyo):

- the field defaults use `2026-10-11` (Asia/Tokyo)
- the daily option uses `2026-10-11` (Asia/Tokyo)
- the weekly option uses Monday `2026-10-12` (Pacific/Kiritimati, UTC+14)

`ng test ngclient --watch=false --include 'projects/ngclient/src/app/backup/schedule-v2/*.spec.ts'`

- Before the fix, the 3 new tests fail (`expected '2026-10-10' to be '2026-10-11'`, `expected '2026-10-11' to be '2026-10-12'`).
- After the fix, all 16 tests in the 2 files pass, including the existing load/save timezone tests in `schedule.component.spec.ts`.
- `tsc -p projects/ngclient/tsconfig.app.json --noEmit` passes (this covers the legacy component, which the test bundle does not include). Prettier `--check` passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
