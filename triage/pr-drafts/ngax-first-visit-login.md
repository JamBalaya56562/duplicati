## Summary
For #5591, which is closed.

When a browser that never logged in opened ngax, the refresh was rejected and ngax could stay on the "Connection lost" dialog instead of going to the login page. This was fixed in #6833 (https://github.com/duplicati/duplicati/commit/f356fd6b146c57912f59ee2489ff2c88e3c742d1). Its tests replace the refresh response with a fake one. This PR only adds a test that does the same first visit against the real server, with no token, and checks that ngax goes to the login page without retrying again and again.

## Testing
- New test `ngaxFirstVisitWithoutToken.spec.ts`. With the changes of #6833 to `AppService.js` and `ServerStatus.js` undone, it fails: `page.waitForURL: Timeout 15000ms exceeded`. On master it passes, together with the two tests in `ngaxAuthRefresh.spec.ts`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
