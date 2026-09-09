# Test that a request with Connection: upgrade is answered normally

Branch: `test/connection-upgrade-header`

A reverse proxy such as nginx set up for WebSockets sends
"Connection: upgrade" on every request, with an empty Upgrade header when
the client did not ask for an upgrade. The old web server answered every
such request with 400; the ASP.NET Core server answers it normally. The
test sends the request on a socket, so it has exactly those headers, with
an empty and a "websocket" Upgrade header. There is no fix to revert, as
the web server was replaced as a whole.

Closes #2949

🤖 Generated with [Claude Code](https://claude.com/claude-code)
