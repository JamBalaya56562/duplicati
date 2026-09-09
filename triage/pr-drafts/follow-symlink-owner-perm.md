## Summary

With `--symlink-policy=follow` a symbolic link is backed up as the file it points to, but its owner and permissions were taken from the link itself. `PosixFile.GetUserGroupAndPermissions` used `UnixFileInfo.GetFileSystemEntry`, which is `lstat`, and `SystemIOLinux.GetMetadata` did not pass `followSymlink` to it. A link always has mode 0777, so with `--restore-permissions` a file that was 0640 came back as a world-writable 0777 file, and a restore as root gave it the owner of the link.

`GetUserGroupAndPermissions` now takes `followSymlink` and uses `stat` (`new UnixFileInfo(path)`) when it is set. Only the metadata collection in `GetMetadata` passes it; the other callers keep the `lstat` behaviour, and nothing changes for `--symlink-policy=store` or for regular files.

Commit: [936628a6b3f8bffc9837c974f59c153e01c81400](https://github.com/JamBalaya56562/duplicati/commit/936628a6b3f8bffc9837c974f59c153e01c81400)

## Testing

- New `FollowSymlinkPermissionsTests.TheOwnerAndPermissionsOfAFollowedLinkTargetAreRestored` (Linux): gives a plain file and a file outside the source folder mode 0640 (and, when run as root, another owner), links to the latter, backs up with `--symlink-policy=follow`, restores with `--restore-permissions` and checks the mode, and as root the owner, of both restored files. The permission check needs no root, so it runs in CI.
- On Linux (WSL, .NET 10, ext4), both as a regular user and as root, the file test fails on master with `link.txt should get the permissions of the file ... But was: ACCESSPERMS` and passes with the fix.
- New `TheOwnerAndPermissionsOfAFollowedFolderLinkTargetAreRestored` does the same for a link to a folder (mode 0750): on master the folder came back as 0777 (`link should get the permissions of the folder ... But was: ACCESSPERMS`), with the fix as 0750. Both tests fail on master and pass with the fix, as a regular user and as root.
- Merged with the xattr fix and #7461 on master e518f734 (before the folder test was added): all three test classes pass, as a regular user and as root.
- No new warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
