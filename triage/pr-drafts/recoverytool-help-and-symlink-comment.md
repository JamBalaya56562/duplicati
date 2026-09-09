## Summary

Two text-only corrections. No code changes.

- **RecoveryTool `recompress` help** (`Duplicati/CommandLine/RecoveryTool/help.txt`):
  - Step 4 said that with `--reupload` "files with old compression are deleted and recompressed files are uploaded back". `Recompress.cs` uploads the recompressed file first (`PutAsync`) and deletes the original after (`DeleteAsync`). The text now says that order.
  - Step 3 now says that `--reencrypt` does not encrypt files that are not encrypted. `Recompress.cs` only re-encrypts when `remoteFile.EncryptionModule != null`, so an unencrypted backup stays unencrypted.
- **`FileRestoreDestinationProvider.WriteMetadata` comment**: it said that applying metadata to a symlink "writes the symlink target, not the symlink itself". Since #7461 the timestamps, owner and access rules are set on the link itself. Only the read-only attribute and the extended attributes still go to the file or folder the link points to on Linux and macOS (`File.SetAttributes` and `setxattr` follow the link). The comment now says that.

Commit: [f034609341b4a87cd261353a28feb9db872074dd](https://github.com/JamBalaya56562/duplicati/commit/f034609341b4a87cd261353a28feb9db872074dd)

## Testing

- `dotnet build` of `Duplicati.Library.SourceProvider.Builtin.csproj` (0 warnings, 0 errors), `Duplicati.CommandLine.RecoveryTool.csproj` and `Executables/Duplicati.CommandLine.RecoveryTool` (0 errors).
- `Duplicati.CommandLine.RecoveryTool.exe help`, Recompress steps 3 and 4.

  Before:
  ```
  3) If --reencrypt is supplied, again reencrypts using same passphrase. If the --new-passphrase option is present, encryption happens using the new passphrase instead (needs to be decrypted for compression type change)
  4) If --reupload is supplied, files with old compression are deleted and recompressed files are uploaded back to remote storage (it is recommended to take at least temporary copy of remote storage before enabling this switch)
  ```
  After:
  ```
  3) If --reencrypt is supplied, again reencrypts using same passphrase. If the --new-passphrase option is present, encryption happens using the new passphrase instead (needs to be decrypted for compression type change). Files that are not encrypted are not encrypted by --reencrypt.
  4) If --reupload is supplied, each recompressed file is uploaded back to remote storage, and then the original file is deleted (it is recommended to take at least temporary copy of remote storage before enabling this switch)
  ```

🤖 Generated with [Claude Code](https://claude.com/claude-code)
