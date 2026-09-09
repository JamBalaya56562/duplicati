"Dismiss all" sent one `DELETE /api/v1/notification/{id}` per notification, all at the same time. With thousands of notifications (warnings accumulate on every run) the browser fails most of them with `net::ERR_INSUFFICIENT_RESOURCES`, and on the server every request re-reads all notifications and signals its own update.

This adds `DELETE /api/v1/notifications`, which removes all notifications in one transaction, clears the unacknowledged warning/error flags and signals a single notification update. The single-notification endpoint is unchanged. The old UI (ngax) now uses the new endpoint for "Dismiss all"; ngclient is updated in duplicati/ngclient (PR to follow).

Measured with 2,001 notifications: 1,000 concurrent single deletes took 1m51s and only 499 succeeded (475 connection refused, 26 timed out); one bulk delete removed the remaining 1,476 in 69 ms.

Tests: `ServerApiIntegrationTests.DeleteAllNotificationsRemovesEveryNotificationInOneRequest_Async` (fails with 405 before this change) and `DeleteNotificationRemovesOnlyThatNotification_Async`.

Fixes #4719

🤖 Generated with [Claude Code](https://claude.com/claude-code)
