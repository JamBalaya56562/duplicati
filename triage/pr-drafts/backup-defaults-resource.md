## Summary
Closes #4554.

The defaults for a new backup, such as AES encryption and a daily schedule, are read from `newbackup.json`, a resource embedded in the server. When the resource could not be found, the error was only logged, and a new backup started without them. This was fixed in https://github.com/duplicati/duplicati/commit/5630c5e34ad27ecca671b77508c06f980b5a955a. That commit changed the type used to find the resource but added no test, so the same break would again go unnoticed. This PR only adds a test.

## Testing
- New test `ServerApiIntegrationTests.BackupDefaultsIncludeTheBuiltInDefaults_Async`. It calls `/api/v1/backupdefaults` and checks for `encryption-module=aes` and `Repeat=1D`. With the resource looked up through `typeof(Server.Runner)` again, as before the fix, it fails: `Expected: not null`, `But was: null`. On master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
