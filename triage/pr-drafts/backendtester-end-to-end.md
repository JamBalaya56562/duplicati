# Run the whole backend tester against a local folder in a test

Branch: `test/backendtester-end-to-end`

The tester was to be checked after the move from .NET Framework. Its
parts have tests, but nothing ran the tool itself. This runs it with two
reruns of three small files against a local folder, and expects exit code
0, "Unittest complete!" and an empty folder at the end.

Closes #4538

🤖 Generated with [Claude Code](https://claude.com/claude-code)
