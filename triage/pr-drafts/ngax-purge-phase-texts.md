## Summary
In the old web UI (ngax), the keys of the purge phases in the table of phase texts ended with a comma (`'PurgeFiles_Begin,'`), so they never matched, and ngax showed the raw phase name, such as `PurgeFiles_Begin`, while purging. The table also had a text for `Repair_Running`, which is not a phase. The commas are removed, and so is the `Repair_Running` entry.

Found while looking at #4121. Phases that have no text in ngax still show their name; adding texts for them needs new strings and is left out here.

## Testing
- New test `NgaxPhaseTextTests.EveryPhaseTextKeyIsAPhaseName`. It reads the table from `ServerStatus.js` and checks every key against `OperationPhase`. On master it fails with `But was: < "Repair_Running", "PurgeFiles_Begin,", "PurgeFiles_Process,", "PurgeFiles_Compact,", "PurgeFiles_Complete," >`. With the change it passes.
- `node --check` passes on `ServerStatus.js`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
