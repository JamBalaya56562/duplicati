Related to #3848

On Linux, the extended attributes of a symbolic link are read from the link itself: `PosixFile.GetExtendedAttributes` uses `llistxattr` and `lgetxattr`. With `--restore-symlink-metadata`, `PosixFile.SetExtendedAttribute` wrote them back with `setxattr`, which follows the link. So the link's attributes were put on the file the link points to, even when that file is outside the restore folder, and the restored link did not get them.

`SetExtendedAttribute` now uses `lsetxattr` whenever `llistxattr` is available, the same check the read side uses. For anything that is not a link, `lsetxattr` and `setxattr` do the same thing.

This is the same kind of problem as the permissions fixed for #3848 (`chmod` following the link), but it is a separate change in a different method.

### Tests

`RestoreSymlinkExtendedAttributesTests` puts a `trusted.*` attribute on a link (Linux allows only `trusted.*` and `security.*` on a symbolic link, and `trusted.*` needs root). It backs up the link, removes it and restores with `--restore-symlink-metadata`. Then it checks that the file the link points to has no such attribute and that the link has it. The test is skipped when not on Linux or not root.

- Linux (WSL, .NET 10, root), before the fix: fails with `the attribute of the link should not be written to the file it points to … But was: < 111, 110, 45, 116, 104, 101, 45, 108, 105, 110, 107 >` (`"on-the-link"`).
- After the fix: passes as root. Together with `SymLinkTests` and `RestoreSymlinkOverExistingDataTests`: 18/18 pass as root. As a normal user the new test is skipped.
- Windows: builds with no new warnings in the touched files, and the new test is skipped.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
