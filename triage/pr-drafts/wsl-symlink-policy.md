Fixes #2171

When WSL creates a symlink that Windows cannot represent as its own symlink (an absolute Linux path such as `/usr/bin/python3`, or a target that does not exist), it stores the link as a reparse point with the tag `IO_REPARSE_TAG_LX_SYMLINK` (`0xA000001D`). `FileInfo.LinkTarget` returns `null` for that tag, so the backup treated the link as a regular file, failed to open it and logged `FileProcessingFailed` on every run, regardless of `--symlink-policy` (including `ignore`, as reported in the issue).

`SystemIOWindows.GetSymlinkTarget` now falls back to reading the reparse data with `FSCTL_GET_REPARSE_POINT` and returns the UTF-8 target of an LX symlink. With that, the existing symlink handling applies:

- `ignore` skips the link without a warning
- `store` (the default) records it as a symlink with its Linux target
- `follow` still warns, since a Linux path cannot be followed from Windows

On restore, the stored link is created as a Windows symlink with the same target string, which WSL reads as the original link (`abs_linux -> /usr/bin/python3`). Recreating it as an LX symlink instead would need a metadata marker and is left out of this change.

Tests (`Issue2171`) create the LX reparse point directly, as WSL writes it, so they need no WSL installation; they are ignored on non-Windows systems. Before the fix all three original tests failed with the `FileProcessingFailed` warnings from the issue; after it, all four pass. I also checked the result manually with symlinks created by `ln -s` in WSL on a `/mnt/c` folder.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
