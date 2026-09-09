`Helper.ExamineDatabaseAsync` decides that a database is a server database when this query returns 2:

    type='table' AND name='Backup' OR name='Schedule'

`AND` binds tighter than `OR`, so an index, view or trigger named `Schedule` was counted as the `Schedule` table. A database with a `Backup` table and such an object was then classified as a server database. The condition is now `type='table' AND (name='Backup' OR name='Schedule')`.

Test: `DatabaseToolExamineDatabaseTests` covers a real server schema plus index, view and trigger variants. The four variants were classified as Server before the change, and all cases pass after.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
