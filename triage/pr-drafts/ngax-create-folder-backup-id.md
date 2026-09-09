## Summary
The server masks the passwords in the destination URL of a saved backup, and puts them back from the saved backup when a request names it. In ngax, the connection test sends the backup ID, but the request that creates a missing destination folder (`/remoteoperation/create`) did not. For a saved backup with a password in its URL, creating the folder then failed with:

```
Unmasked URL contains password placeholder
```

The create request now sends `backupId` the way the connection test does. ngclient uses the V2 test with `AutoCreate` on current servers, so it is not affected.

## Testing
- New Playwright test `ngaxCreateFolderBackupId.spec.ts`. It opens a saved backup, answers the connection test with `missing-folder`, accepts creating the folder, and checks the create request. On master it fails with `Expected: "42"`, `Received: undefined`. With the change it passes.
- By hand against a real server: a saved WebDAV backup to `localhost:1` with `auth-password` in its URL. With only the connection test answered by the browser, the real create request returned `Unmasked URL contains password placeholder` on master. With the change the server put the password back and tried to connect (connection refused).
- The ngax Playwright tests `ngaxCreateFolderBackupId`, `ngaxEditKeepsMetadata`, `ngaxDialogEnter`, `ngaxPages`, `ngaxOAuth` and `ngaxWithoutJquery`: 22 passed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
