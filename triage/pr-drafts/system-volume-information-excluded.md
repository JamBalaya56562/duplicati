## Summary
Closes #4045.

A backup of a whole drive tried to list "System Volume Information", which a user without the backup privilege may not read, and reported a warning for it. Since #7258 the folder is left out before it is listed. That PR added no test. This PR only adds a test.

## Testing
- New tests in `SystemVolumeInformationExcludeTests`, on Windows only. The folder at the root of a drive, marked hidden and system, is left out. A folder with the same name that is not marked so, or that is not at the root, is kept. With the exclusion turned off, `TheSystemVolumeInformationFolderOfADriveIsLeftOut` fails: `Expected: False`, `But was: True`. On master both pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
