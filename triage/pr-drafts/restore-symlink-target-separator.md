## Summary

A relative symbolic link stores its target with the separators of the system it was backed up on, and the restore created the link with that target unchanged:

- Windows → Linux/macOS: `sub\up -> ..\real.txt` was restored as `up -> ..\real.txt`. There the backslash is part of a name, so the link did not resolve.
- Linux → Windows: `sub/up -> ../real.txt` was restored with the target `../real.txt`. Windows does not resolve a slash in a link target, and reading through the link fails with "The filename, directory name, or volume label syntax is incorrect".
- Linux → Windows, with a backslash in a name: `sub/bs -> ../weird\name.txt`. The file itself is restored as `weird_name.txt`, but the link kept `../weird\name.txt`.

The restore already maps the backed up paths between the two systems (`LocalRestoreDatabase.SetTargetPathsAsync`). Link targets now get the same mapping, decided the same way (`Util.GuessDirSeparator` on the backed up path).

`RestoreHandler.MapSymlinkTargetSeparators` handles both directions:

- From Windows, restored elsewhere: a relative target has `\` replaced with `/`.
- From elsewhere, restored on Windows: a relative target has `\` replaced with `_`, then `/` replaced with `\`. This is the same order the restored paths use, so `../weird\name.txt` becomes `..\weird_name.txt`.
- An absolute target names a place on the machine the backup was made on, and is kept as it is. From Windows that is `C:\...`, `C:...`, `\...`, `\\server\share\...` or `\\?\...`; from elsewhere it is `/...`.
- A restore on the same kind of system is never changed. For example, a Linux link whose target has a backslash in a name keeps it on Linux.

`ApplyMetadataAsync`, which both engines use, applies the mapping. The new engine decides per file from its original path. The legacy engine decides once per restore from the restored paths.

## Testing

`RestoreSymlinkTargetSeparatorTests`:

- `MapsOnlyRelativeTargetsFromTheOtherSystem` (15 cases) covers the mapping in both directions: absolute targets, UNC, `\\?\`, and restores on the same kind of system.
- `RestoredLinkFromTheOtherSystemResolves` restores a link through `RestoreHandler.ApplyMetadataAsync` and `FileRestoreDestinationProvider` into a real folder. It then reads the link back and reads the file through it. The Windows → Linux case runs only off Windows; the Linux → Windows cases run only on Windows.

Results:

- Windows → Linux (WSL, .NET 10): with the mapping turned off, 3 tests fail, e.g. `Expected: "../real.txt" But was: "..\\real.txt"`. With the fix, 16 pass and 2 are skipped (Windows only).
- Linux → Windows (Windows): with the reverse mapping turned off, 5 tests fail, e.g. `Expected: "..\\weird_name.txt" But was: "../weird\\name.txt"`. With the fix, 17 pass and 1 is skipped (Linux only).
- The touched files build on Windows with no new warnings.

End to end, with both engines (`--restore-legacy` false and true):

- Windows → Linux: I backed up `sub\up -> ..\real.txt` with the Windows CLI and restored it with the Linux CLI in WSL, to ext4. I also tried `--allow-restore-outside-target-directory` false and true.
  - master: `readlink` shows `..\real.txt`, and `cat` fails with "No such file or directory".
  - this branch: `readlink` shows `../real.txt`, and `cat` prints `real`.
- Linux → Windows: I backed up `sub/up -> ../real.txt` and `sub/bs -> ../weird\name.txt` with the Linux CLI on ext4 and restored them with the Windows CLI.
  - before: both links fail to open with ERROR_INVALID_NAME.
  - this branch: `up` points to `..\real.txt` and reads `real`; `bs` points to `..\weird_name.txt` and reads `weird`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
