# Test duplicati-server-util import against a running server

Branch: `test/serverutil-import`

duplicati-server-util replaced the ConfigurationImporter tool, which was
to be checked after the move from .NET Framework. The server side of the
import has integration tests, but the tool's own request did not. This
exports a configuration and imports it with the tool's Connection against
the test server, and expects a new backup to be listed.

Closes #4540

🤖 Generated with [Claude Code](https://claude.com/claude-code)
