## Summary

Two text-only corrections. No code changes.

- **RecoveryTool `recompress` help** (`Duplicati/CommandLine/RecoveryTool/help.txt`), step 4: it said that with `--reupload` "files with old compression are deleted and recompressed files are uploaded back". `Recompress.cs` uploads the recompressed file first (`PutAsync`) and deletes the original after (`DeleteAsync`), and since #7551 it skips the delete when the upload kept the same name and so replaced the original. The text now says that.
- **`FileRestoreDestinationProvider.WriteMetadata` comment**: it said that applying metadata to a symlink "writes the symlink target, not the symlink itself". With #7461, #7546 and #7596, what is applied goes to the link itself, and outside Windows the permissions and the file attributes of a link are skipped, because `chmod` would change the file the link points to. The comment now says that.

Commit: [e15f9564a7a72f997a4186dfc67f954474a74445](https://github.com/JamBalaya56562/duplicati/commit/e15f9564a7a72f997a4186dfc67f954474a74445)

## Testing

- `dotnet build` of `Executables/Duplicati.CommandLine.RecoveryTool` (which builds `Duplicati.Library.SourceProvider.Builtin`): no warnings in the changed files.
- `Duplicati.CommandLine.RecoveryTool.exe help`, Recompress step 4.

  Before:
  ```
  4) If --reupload is supplied, files with old compression are deleted and recompressed files are uploaded back to remote storage (it is recommended to take at least temporary copy of remote storage before enabling this switch)
  ```
  After:
  ```
  4) If --reupload is supplied, each recompressed file is uploaded back to remote storage, and then the original file is deleted, unless the upload replaced it because the name did not change (it is recommended to take at least temporary copy of remote storage before enabling this switch)
  ```
- The behaviour the comment describes is what `RestoreSymlinkMetadataTests` and `RestoreSymlinkExtendedAttributesTests` check. On Linux (WSL, ext4), on this branch: 12 passed and 1 skipped (the extended attribute test needs root) as a normal user, and 13 passed as root.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
