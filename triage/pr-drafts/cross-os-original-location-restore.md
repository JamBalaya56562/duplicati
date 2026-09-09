## Summary

When a backup made on Windows is restored on Linux or macOS without `--restore-path`, `LocalRestoreDatabase.SetTargetPathsAsync` is meant to restore `C:\Data\file.txt` below a root folder named after the drive letter, as `/C/Data/file.txt`. The comment in the code says it uses "the drive letter as root folder".

Two updates run one after the other:

1. The first update maps the drive letter.
2. The second update handles UNC paths. For any path that is not UNC, it fell back to `ELSE "Path"`, which put back the original `C:\Data\file.txt`.

After the separators were mapped, the target became `C:/Data/file.txt`. That is a relative path, so the files were restored below a folder named `C:` in the working folder. Both restore engines did this.

The second update now falls back to `ELSE "Targetpath"`, as the same pair of updates already does in the `--restore-path` branch. UNC paths are handled as before.

## Testing

`RestoreWindowsPathsToOriginalLocationTests.RestoresBelowTheDriveLetterFromTheRoot` (both engines) works like this:

- It backs up a folder, then rewrites the stored path prefixes in the local database to Windows paths (`C:` + the path with `\`).
- It then restores with `--dry-run` and no `--restore-path`, and checks the folders the restore reports it would create.
- It is skipped on Windows.
- It sets `--skip-restore-verification`, because the legacy engine checks the restored files even in a dry run.

Results:

- Linux (WSL, .NET 10), before the fix: both cases fail with `Would create folder: C:/home/jam/.../backup-data/sub/`. After the fix, 2/2 pass.
- Windows: builds with no new warnings in the touched files. Both cases are skipped.
- End to end: I backed up a folder with the Windows CLI and restored it with the Linux CLI in WSL. I ran it as root from an empty working folder without `--restore-path`, with both engines:
  - master: the files were written to `<working folder>/C:/Users/Jam/...`.
  - this branch: the files were written to `/C/Users/Jam/...`, and nothing was written in the working folder.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
