Repository: duplicati/documentation
Branch: `docs/recoverytool-recompress-steps` (from `main@upstream` a8f660252ed0db49614d47f8abe0d41a5d4bfd9f)
Title: Fix the RecoveryTool recompress steps
Companion of the duplicati branch `fix/recoverytool-help-and-symlink-comment` (same wording in `help.txt`); this docs change does not depend on it, the text matches what the current release does.

## Summary

The Recompress steps in `duplicati-programs/command-line-interface-cli-1/recoverytool.md` did not match what `recompress` does:

- Step 4 said that with `--reupload` "files with old compression are deleted and recompressed files are uploaded back". `Recompress.cs` uploads each recompressed file first (`PutAsync`) and deletes the original after it (`DeleteAsync`). The step now says that order.
- Step 3 now says that `--reencrypt` does not encrypt files that are not encrypted. `Recompress.cs` only re-encrypts when the remote file already has an encryption module, so an unencrypted backup stays unencrypted.

The `--new-passphrase` / `--reupload` warning below the steps is unchanged.

Commit: [a5957b5ecee2e176610ca5be8e5a09dce3acc18b](https://github.com/JamBalaya56562/documentation/commit/a5957b5ecee2e176610ca5be8e5a09dce3acc18b)

## Testing

- Checked against `Duplicati/CommandLine/RecoveryTool/Recompress.cs` on duplicati master 98067e41a555b965caad931a5155e61231f5eced: `PutAsync` then `DeleteAsync` (lines 283-284), and `if (reencrypt && remoteFile.EncryptionModule != null)` (line 265).
- The file keeps LF line endings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
