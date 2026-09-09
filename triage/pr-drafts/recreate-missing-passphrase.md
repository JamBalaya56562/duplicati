## Summary
For #5007, which is closed.

Recreating the database of an encrypted backup without the passphrase went through every remote file and failed on each one. Since https://github.com/duplicati/duplicati/commit/73a2f32b05a77afa56691aaf85a21c0b2ad56369 it stops before reading any file, with "The remote files are encrypted, but no passphrase was provided". That commit added no test. This PR only adds a test.

## Testing
- New test `Issue5007.RecreatingAnEncryptedBackupWithoutThePassphraseStopsAtOnceAsync`. It makes an encrypted backup, deletes the local database, and repairs with `--no-encryption=true` and no passphrase. It expects a `UserInformationException` with `MissingPassphrase`. Without the check it fails with `ArgumentException: Stream must be readable`. On master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
