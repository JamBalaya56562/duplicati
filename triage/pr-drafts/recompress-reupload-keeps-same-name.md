## Summary

`Duplicati.CommandLine.RecoveryTool recompress ... --reupload` uploads the recompressed volume and then deletes the original by name. When the target compression module is the same as the source (e.g. `zip` → `zip` without encryption, or with `--reencrypt` using the same encryption module), the uploaded file has the same name as the original. The upload overwrites it, and the following delete removes the newly uploaded file, so the destination ends up empty.

This was reported on the forum with 2.4.0.0, where `recompress zip "test 1" tmp --passphrase=password --reencrypt --reupload` left both the destination and the working folder empty: https://forum.duplicati.com/t/22760

The fix skips the delete when the uploaded name equals the original name. When the names differ (format change, or decrypting without `--reencrypt`), the original is still deleted as before.

The forum user's goal was to add encryption to an unencrypted backup with `--reencrypt`. `--reencrypt` only re-encrypts files that are already encrypted, so on an unencrypted backup it silently did nothing. Recompress now prints a warning in that case (`Warning: N of M files are not encrypted, so --reencrypt has no effect on them and they stay unencrypted`). The behaviour and exit code are unchanged.

Commit: [f807349329865d4c449f9a32420ffb58a2dd63b4](https://github.com/JamBalaya56562/duplicati/commit/f807349329865d4c449f9a32420ffb58a2dd63b4)

## Testing

- Added `RecoveryToolTests.RecompressSameFormatWithReuploadKeepsRemoteFilesAsync` (encrypted with `--reencrypt`, and `--no-encryption`): backs up to a `file://` destination, runs `recompress zip ... --reupload`, checks that the remote file list is unchanged, and recreates the database from the destination.
  - Before the fix both cases fail: `Expected is <System.String[3]>, actual is <System.String[0]>`.
  - After the fix both pass.
- Added `RecoveryToolTests.RecompressReencryptWarnsAboutUnencryptedFilesAsync`: an unencrypted backup recompressed with `--reupload --reencrypt` exits with 0, leaves the same unencrypted files, and prints the warning.
  - Before the change it fails: `Expected: String containing "are not encrypted, so --reencrypt has no effect on them"`.
  - After the change it passes.
- Existing `RecompressAsync` and `RecompressAndRecreateDatabaseAsync` (zip → tzstd with `--reupload`, which asserts that no `.zip` files remain) still pass: `dotnet test --filter "FullyQualifiedName~RecoveryToolTests.Recompress"` → 7 passed, 0 failed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
