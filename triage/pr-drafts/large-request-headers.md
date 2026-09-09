# Test that requests with large cookie headers are answered

Branch: `test/large-request-headers`

A browser sends every cookie set for the host name, including those of
other applications on it. The old web server answered a request with more
than a few kilobytes of headers with 400; Kestrel allows 32 KB. The test
sends cookie headers of 4,600, 16,000 and 30,000 bytes to an API call and
expects 200. With Kestrel limited to 4 KB of headers, as a check, all
three fail.

Closes #4627

🤖 Generated with [Claude Code](https://claude.com/claude-code)
