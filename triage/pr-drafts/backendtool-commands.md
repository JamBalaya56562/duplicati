# Test every BackendTool command against a local folder

Branch: `test/backendtool-commands`

The tool was to be checked after the move from .NET Framework. The
existing test covers GET only; this runs CREATEFOLDER, PUT, LIST, GET and
DELETE in turn against a local folder and checks the result of each.

Closes #4539

🤖 Generated with [Claude Code](https://claude.com/claude-code)
