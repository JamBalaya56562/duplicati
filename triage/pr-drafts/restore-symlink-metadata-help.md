## Summary

The help for `--restore-symlink-metadata` said that applying metadata to a symlink "will usually mean changing the symlink target". That is no longer the case:

- #7461 (for #3848) sets the owner on the link itself and stops applying the permissions through the link on Linux and macOS.
- #7546 skips the file attributes of a link outside Windows, where the read-only attribute is set with `chmod` and would change the target.
- #7596 writes the extended attributes of a link with `lsetxattr`, so they go to the link itself.

The text now says what the option does today:

- The timestamps and extended attributes, and with `--restore-permissions` the owner and access rules, are set on the symlink itself.
- On Linux and macOS, the permissions and the file attributes (such as read-only) of a symlink are not restored, as setting them would change the file or folder the symlink points to.

Only the long help string changes. No behaviour changes.

Commit: [0bea7049ca146aebca3c89b75b117a43ec84a4f0](https://github.com/JamBalaya56562/duplicati/commit/0bea7049ca146aebca3c89b75b117a43ec84a4f0)

## Testing

The tests that cover these points pass on Linux (WSL, ext4) on this branch: `RestoreSymlinkMetadataTests` (owner on the link, target's permissions and read-only state unchanged, both restore engines) and `RestoreSymlinkExtendedAttributesTests` (the attribute ends up on the link, not the target). As a normal user 12 passed and 1 was skipped (the extended attribute test needs root); as root all 13 passed.

The timestamps were checked earlier with a small probe that restores a link to a file outside the restore folder with `restoreSymlinkMetadata: true`: on Windows and on Linux the link got the times and the target was unchanged. On Windows the attributes (`Hidden`) and the access rules (`icacls /L`) also ended up on the link. macOS was not run; the ACL and file flags use the link-only calls there.

`help restore-symlink-metadata` before and after (Windows build):

```
  --restore-symlink-metadata (Boolean): Apply metadata to symlinks
    If symlink metadata is applied, it will usually mean changing the symlink
    target, instead of the symlink itself. For this reason, metadata is not
    applied to symlinks, but this option can be used to override this, such
    that metadata is applied to symlinks as well.
    * default value: false
```

```
  --restore-symlink-metadata (Boolean): Apply metadata to symlinks
    Use this option to apply the stored metadata to restored symlinks as well.
    By default, it is not applied to them. The timestamps and extended
    attributes, and with --restore-permissions the owner and access rules,
    are set on the symlink itself. On Linux and macOS, the permissions and
    the file attributes (such as read-only) of a symlink are not restored, as
    setting them would change the file or folder the symlink points to.
    * default value: false
```

The build of `Duplicati.CommandLine` has no warnings in `Strings.cs`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
