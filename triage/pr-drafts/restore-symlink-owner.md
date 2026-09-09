Fixes #3848

Symbolic links are not given their owner on restore by default, because `--restore-symlink-metadata` is off. The help text for that option says that applying metadata to a link usually changes the link's target. On Linux, turning it on together with `--restore-permissions` showed what that means:

- The link itself did get its owner and group back. `UnixSymbolicLinkInfo.SetOwner` uses `lchown`.
- The permissions were then set with `chmod`, which follows the link. The link's stored mode is always `0777`, so the file the link points to became world-writable. When the link points outside the restore folder, as an absolute link does, that file is not part of the restore at all.

A symbolic link has no permissions of its own to restore, so `PosixFile.SetUserGroupAndPermissions` now sets the permissions only on entries that are not links. The owner is still set, through `lchown`.

The timestamps are already safe: the new test checks that the target's last-write time is unchanged.

### Tests

`RestoreSymlinkMetadataTests` backs up a link and the file it points to, then restores them with every combination of `--restore-symlink-metadata`, `--restore-permissions` and `--restore-legacy`. It checks that the target's owner, mode and timestamp are unchanged and, when both options are on, that the restored link has its owner. As root it uses separate uids/gids for the link and the target. Without root it uses the current user, so CI still covers the permission check. It is skipped on Windows.

- Linux (WSL, .NET 10), before the fix: `(True,True,True)` and `(True,True,False)` fail with `the permissions of the link target changed … But was: OtherExecute, OtherWrite, OtherRead, …`. Same result as root and as a normal user.
- After the fix: 8/8 pass as root and as a normal user. `SymLinkTests` and `RestoreSymlinkOverExistingDataTests` pass as root (25/25 together).
- Windows: builds with no new warnings in the touched files. `SymLinkTests` and `RestoreSymlinkOverExistingDataTests` pass, and the new test is skipped.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
