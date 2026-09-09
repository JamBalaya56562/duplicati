Part of #6607

## Summary
A failed GPG decryption was only seen when the error output of GPG held `decryption failed:`. GPG writes its messages in the language of the system, so with a localized GPG the decryption failure went unnoticed, and the empty output went on to the archive reader. The log in #6607 is from a Russian system and shows the archive errors (`Central Directory corrupt`) instead of a decryption error.

A decryption that exits with a code other than 0 now fails with a `CryptographicException` that holds the GPG error output. When GPG was stopped because the copy failed, the copy error is still the one reported. Encryption is not changed.

The main request in #6607, backing up without the private key, is not addressed here.

## Testing
- New test `GPGEncryptionTests.DecryptReportsLocalizedGpgFailure`, with the existing stand-in for gpg writing a French message and exiting with 2. On master no exception is thrown (`Expected: <System.Security.Cryptography.CryptographicException>`, `But was: null`). With the change it passes.
- Tests matching `GPG`: 15 passed, including the existing tests for a gpg that stops reading and for an output that cannot be written. No new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
