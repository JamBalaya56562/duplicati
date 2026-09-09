# Test that a folder with a Firefox style lock link backs up repeatedly

Branch: `test/dangling-lock-symlink`

Firefox keeps a "lock" symlink in its profile folder that points to
"host:+pid", which does not exist. A profile folder with it used to stop
every backup with "UNIQUE constraint failed: FilesetEntry.FilesetID,
FilesetEntry.FileID". The test backs up such a folder, with a dangling
link next to it, three times: then with a changed file, then with the
lock link made again with another target. Each backup is clean and the
link is in every version. The commit that fixed it is not known; this
pins down the behaviour of current master.

Closes #3753

🤖 Generated with [Claude Code](https://claude.com/claude-code)
