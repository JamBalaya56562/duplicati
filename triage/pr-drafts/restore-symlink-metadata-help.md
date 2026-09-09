## Summary

The help for `--restore-symlink-metadata` said that applying metadata to a symlink "will usually mean changing the symlink target". Since #7461 (for #3848) the permissions are no longer applied through the link on Linux, and the owner is set on the link itself. The text now says what the option does today:

- The timestamps, and with `--restore-permissions` the owner and access rules, are set on the symlink itself.
- On Linux and macOS, the permissions of a symlink are not restored, and the read-only attribute and extended attributes are applied to the file or folder the symlink points to.

Only the long help string changes. No behaviour changes.

## Testing

The text was checked against what `FileRestoreDestinationProvider.WriteMetadata` (used by both restore engines) actually does with `restoreSymlinkMetadata: true`, using a small probe that restores a link to a file outside the restore folder:

- Windows (file symlink): last write time, creation time, attributes (`Hidden`) and the access rules all ended up on the link (`icacls /L`); the target was unchanged.
- Linux (WSL, ext4, as root and as a normal user): the link got the times and the owner (uid 12345 on the link, the target kept uid 0); the permissions were not applied to either. The stored `ReadOnly` attribute changed the target from 644 to 444, and the `user.*` extended attribute was written to the target, not the link.
- macOS: from reading the code only (the ACL and file flags use the link-only calls; the owner and the extended attributes go through the same code as Linux).

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
    By default, it is not applied to them. The timestamps, and with
    --restore-permissions the owner and access rules, are set on the symlink
    itself. On Linux and macOS, the permissions of a symlink are not
    restored, and the read-only attribute and extended attributes are applied
    to the file or folder the symlink points to instead.
    * default value: false
```

The build of `Duplicati.CommandLine` shows the same warnings before and after, none in `Strings.cs`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
