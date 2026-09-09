## Summary

On Windows, a WebDAV share mapped to a drive letter (WebClient redirector) cannot be used as a source: the file picker fails and a backup never finishes.

The WebDAV redirector reports directory entry names with a trailing null character. .NET's enumeration (unlike .NET Framework's, which 2.0.8 used) takes the reported length as is, so every entry comes back as e.g. `W:\b.txt\0`, and the `.`/`..` entries are no longer filtered out. This is [dotnet/runtime#49803](https://github.com/dotnet/runtime/issues/49803), still open. As a result:

- the file picker (`/api/v1/filesystem`) fails with "Null character in path", because `ListFolderAsNodes` calls `GetFileAttributes` on each entry
- a backup recurses into `..` without end (`W:\sub\..\sub\..\sub\..\…`)

This adds `SystemIOWindows.RemoveTrailingNullEntries`, which trims the trailing null and drops `.`/`..`, and applies it to every path-returning enumeration in `SystemIOWindows` (`EnumerateFileSystemEntries`, `EnumerateFiles`, `EnumerateDirectories`, `GetFiles`, `GetDirectories`). Entries without a trailing null are returned unchanged, so local and SMB listings are unaffected. The File backend already trims these nulls for destinations (#6449); this does the same for the source side. Commit: [8ec6841b624a6a56ac332a2d3a49b325365667c7](https://github.com/JamBalaya56562/duplicati/commit/8ec6841b624a6a56ac332a2d3a49b325365667c7).

## Testing

- `IOTests.TestRemoveTrailingNullEntriesInWindowsClient` (new): fails when the helper returns its input unchanged (`Expected: "W:\\b.txt" But was: "W:\\.\0"`), passes with this change. All 7 `IOTests` pass.
- Manual, Windows 11, WsgiDAV on 127.0.0.1 mapped with `net use W: http://127.0.0.1:8090/`, containing `b.txt` and `sub\a.txt`:
  - `SystemIOWindows.EnumerateFileSystemEntries("W:\")` before: `W:\.\0, W:\..\0, W:\b.txt\0, W:\sub\0`, then `GetFileAttributes` throws "Null character in path". After: `W:\b.txt, W:\sub`.
  - CLI backup of `W:\` before: still recursing into `..` after 2 minutes (1,303 "Including path" lines). After: completes with "Files added: 2", and a restore gives back both files with the right contents.
- No new compiler warnings in the touched files.

Backing up such a drive still logs one "Failed to process metadata" warning per entry, because reading the ACL fails on WebDAV (`InvalidOperationException: Method failed with unexpected error code 1`). That is a separate issue and is not changed here.

Fixes #5786

🤖 Generated with [Claude Code](https://claude.com/claude-code)
