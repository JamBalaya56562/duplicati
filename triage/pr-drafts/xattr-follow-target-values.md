## Summary

With `--symlink-policy=follow` a symbolic link is backed up as the file it points to, but the extended attributes of that file were lost. `PosixFile.GetExtendedAttributes` listed the attribute names with `listxattr`, which follows the link, and then read every value with `lgetxattr`, which reads the link itself. The link has none of those attributes, so each lookup failed and the attribute was silently dropped. A restore then brings back the file content without its attributes, while a plain file next to it keeps them.

The values are now read the same way as the names: `getxattr` when the link is followed, `lgetxattr` otherwise. Nothing changes when the link is stored (`--symlink-policy=store`) or for regular files.

Commit: [35adeff108cdaa9ce8d844eeee092570f14d9175](https://github.com/JamBalaya56562/duplicati/commit/35adeff108cdaa9ce8d844eeee092570f14d9175)

This touches only the read side; writing the attributes of a stored symlink is a separate change and does not overlap with this one.

## Testing

- New `FollowSymlinkExtendedAttributesTests.AnAttributeOfAFollowedLinkTargetIsRestored` (Linux, non-root, `user.*` attribute, so it runs in CI): puts the attribute on a plain file and on a file outside the source folder, links to the latter, backs up with `--symlink-policy=follow`, restores to a new folder and checks that both restored files have the attribute.
- On Linux (WSL, .NET 10, non-root, ext4) the test fails on master with `the followed link should get the attribute of its target ... But was: null` and passes with the fix.
- Rebased on master 12553b54 and merged with #7461 and the owner/permission fix: the test passes, as a regular user and as root.
- No new warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
