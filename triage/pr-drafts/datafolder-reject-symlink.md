Fixes #7472

# Reject a data folder that is a symbolic link with a clear message

As decided in #7472, symbolic links are rejected, and `--allow-insecure-datafolder` remains the way around it. Until now they were rejected for the wrong reason: the check reads the folder with `lstat`, so for a link it reported the mode of the link itself, `permissions allow group or other access (777)`. It then suggested `secure-datafolder`, which changed the folder the link points to and could never make the check pass.

- `SystemIOLinux.HasPermissionUserRWOnly` reports `it is a symbolic link` for a link. A trailing slash is trimmed first, as `lstat` on `link/` looks at the target.
- `DataFolderManager` throws a message that says the data folder is a symbolic link, which is not accepted, and points to the folder itself or `--allow-insecure-datafolder`. The help id stays `InsecureDataFolderPermissions`.
- The preload settings check says the same for the directory that holds `preload.json`.
- `secure-datafolder` stops at a link, with exit code 1, instead of changing the folder it points to.

Windows is unchanged. The new checks run only outside Windows, as the issue and the `lstat` problem are POSIX only.

## Testing

New tests in `DataFolderSecurityTests`, which run on Linux and macOS: the check on a link (with and without a trailing slash), `PrepareSecureDataFolder` on a link rejected with the new message, and accepted with `--allow-insecure-datafolder`. In WSL (Ubuntu, .NET 10, regular user):

- Before: 2 failed. The check reported `permissions allow group or other access (777)`, and the message suggested `secure-datafolder`.
- After: 14 passed, 3 skipped. The skipped tests need root, as before.

`secure-datafolder --apply` in WSL on a link to a folder with mode 0700 now prints "The data folder is a symbolic link, which is not accepted as the data folder", exits with 1, and leaves the folder alone. On the folder itself it still reports that no changes are needed and exits with 0.

I did not run the preload check with a linked directory.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
