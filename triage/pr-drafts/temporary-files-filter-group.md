# Test that the TemporaryFiles filter group excludes .tmp files by name

Branch: `test/temporary-files-filter-group`

The "Temporary files" exclusion goes by the Temporary attribute, which
programs such as Chrome do not set on their .tmp files. The name based
{TemporaryFiles} filter group excludes them; this pins that down.

Closes #1838

🤖 Generated with [Claude Code](https://claude.com/claude-code)
