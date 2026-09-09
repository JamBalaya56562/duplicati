# Test that a source file gone when it is read is left out with a warning

Branch: `test/vanished-source-file`

A file that is listed and then removed before it is read, as temporary
files often are, used to stop the whole backup with a
FileNotFoundException. It is now reported as a PathNotFound warning and
the other files are backed up. The test uses a source provider whose file
throws FileNotFoundException when it is opened.

Closes #2642

🤖 Generated with [Claude Code](https://claude.com/claude-code)
