## Summary

On Linux and macOS, restoring a symbolic link with `--restore-symlink-metadata=true` applied the stored `CoreAttributes` to the file the link points to. The read-only attribute is set with `File.SetAttributes`, which uses `chmod` and follows the link, so:

- a link backed up while its target was read-only made the target read-only (644 → 444) on restore, and
- a link backed up while its target was writable made a read-only target writable again (444 → 644).

This is the same kind of problem as #3848: #7461 stopped the permissions of a link from being written to its target, but the attributes path was left. A link cannot have permissions of its own on Linux, and its permissions are not restored on macOS either since #7461, so the attributes are now skipped for a link outside Windows. Windows is unchanged: there the attributes are set on the link itself.

One side effect on macOS: .NET sets the hidden attribute with `lchflags`, on the link itself, so it used to be restored on a link together with the read-only change. It is skipped now as well. With `--restore-permissions`, the hidden flag is still restored on the link through `macos:flags`; without it, a link's hidden flag is not restored on macOS.

- [cf1496afeed253334f81d474cc7d1aab1a8106c2](https://github.com/JamBalaya56562/duplicati/commit/cf1496afeed253334f81d474cc7d1aab1a8106c2) Do not chmod the target of a restored symlink

## Testing

- New `RestoreSymlinkMetadataTests.RestoredSymlinkDoesNotChangeTheReadOnlyStateOfItsTargetAsync` (read-only at backup × legacy restore), which does not need root. Measured on Linux (WSL, ext4, non-root):
  - without the fix: 4 of 4 fail, e.g. `Expected: GroupRead, UserWrite, UserRead` / `But was: GroupRead, UserRead`, and the reverse direction
  - with the fix: `RestoreSymlinkMetadataTests|SymLinkTests|RestoreSymlinkOverExistingDataTests` 29 passed, 0 failed
- Read-only restore of regular files still works: `Issue6068FileAndFolderAttributesAndPermissionsAsync` 8 passed on Linux with the fix.
- Windows: `Duplicati.UnitTest` builds with no errors and no warnings in the touched files; the new test is not run there (`UnsupportedOSPlatform("windows")`), and the change does not alter the Windows path.
- macOS was not run.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
