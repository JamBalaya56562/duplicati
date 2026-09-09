"Dismiss all" sent one DELETE request per notification through `forkJoin`, all at once, which fails with `net::ERR_INSUFFICIENT_RESOURCES` when there are thousands of notifications (duplicati/duplicati#4719). This switches to the new `DELETE /api/v1/notifications` endpoint and restores the list if the request fails.

The API client is regenerated (`update:openapi`) from a server build with the new endpoint; the only swagger change is the new `delete` operation.

**Depends on duplicati/duplicati#<PR>**: against a server without the endpoint, "Dismiss all" gets a 405 and the list is restored. Please merge after the server change.

Tests: new specs in `notifications.state.spec.ts` (one request for 2,000 notifications; restore on error).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
