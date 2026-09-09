# Test that a database inconsistency is reported with its own message

Branch: `test/database-inconsistency-message`

A backup stopped by a database inconsistency used to report only "One or
more errors occurred", the message of the AggregateException that wrapped
the real one. The test makes a blockset's length disagree with its blocks
and expects the backup to fail with DatabaseInconsistencyException itself,
whose message names the file and says to run repair. Wrapping the
exception in an AggregateException, as a check, brings back the old
message and fails the test.

Closes #3286

🤖 Generated with [Claude Code](https://claude.com/claude-code)
