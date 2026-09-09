## Summary
Closes #2263.

Listing the OneDrive folder of a backup over 400 GB timed out, because the whole listing had to finish within one timeout. The Microsoft Graph backends now apply `--list-timeout` to each page of the listing (`Enumerate` in `MicrosoftGraphBackend`), but no test covered it. This PR only adds a test.

## Testing
- New test `MicrosoftGraphListTimeoutTests.ListingOfManyPagesMayTakeLongerThanTheListTimeoutAsync`. A stub Graph lists the folder in three pages linked with `@odata.nextLink`, each answering in 1.5 s, with `--list-timeout=3s`. With one timeout for the whole listing it fails with `TaskCanceledException` after 3 s. On master it passes in about 4.5 s.

🤖 Generated with [Claude Code](https://claude.com/claude-code)