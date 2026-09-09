# Test that a failed quota request is retried

Branch: `test/quota-request-retry`

Reading the quota used to be a single request outside the retry handling,
so one failed request, such as the 404 OneDrive sometimes returned, failed
the whole backup. It now goes through the backend manager's retries. The
test uses a destination whose first quota request fails with a 404, and
expects the backup to complete.

Closes #4015

🤖 Generated with [Claude Code](https://claude.com/claude-code)
