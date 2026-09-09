Fixes #7524

# Restore the owner of symlinks with --restore-permissions alone

As agreed in #7524 (option A): a restored symbolic link got its owner back only when both `--restore-symlink-metadata` and `--restore-permissions` were set, because `FileRestoreDestinationProvider.WriteMetadata` returns before any metadata for a link without the first. The owner is set with `lchown` (`UnixSymbolicLinkInfo.SetOwner`), which does not follow the link, so it does not have the problem that made `--restore-symlink-metadata` opt-in.

Now, with `--restore-permissions` and without `--restore-symlink-metadata`, only the owner entries (`unix:uid-gid-perm`, `unix:owner-name`, `unix:group-name`) are applied to the link through `SetMetadata`. `PosixFile.SetUserGroupAndPermissions` already skips the mode for a link. Timestamps, extended attributes and the macOS ACL and flags still need `--restore-symlink-metadata`.

Both restore engines go through this method.

## Testing

`RestoredSymlinkGetsItsOwnerAndLeavesItsTargetAloneAsync` now expects the owner whenever `--restore-permissions` is set. Run as root in WSL (Ubuntu, .NET 10), where the link and its target have different owners:

- Before: 2 of 8 failed, the `(restoreSymlinkMetadata: false, restorePermissions: true)` case on both engines ("the restored link did not get its owner / group").
- After: 8 of 8 pass. The test also checks that the target of the link keeps its own owner, mode and time.

As a regular user, `RestoreSymlinkMetadataTests` and `RestoreSymlinkExtendedAttributesTests` pass: 12 passed, 1 skipped.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
