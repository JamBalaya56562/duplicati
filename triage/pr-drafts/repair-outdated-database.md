# Test that repair refuses an outdated local database

Branch: `test/repair-outdated-database`

A machine restored to an earlier state also gets its earlier local
database back. Repair now compares the newest remote file with the newest
local fileset and stops; this test restores the database from before the
second backup, expects RemoteFilesNewerThanLocalDatabase, and checks that
the destination is left as it was.

Closes #3223

🤖 Generated with [Claude Code](https://claude.com/claude-code)
