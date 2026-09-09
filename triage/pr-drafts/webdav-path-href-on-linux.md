Fixes #6748

## What happens

A WebDAV server lists a folder by answering PROPFIND with an href for each entry, and many servers give only the path, such as `/dav/Duplicati/%23Photo/duplicati-….dlist.zip.aes`. The parser added in #6591 ([`8907911e8d8585c3152a2da64b9076bd49ced1c4`](https://github.com/duplicati/duplicati/commit/8907911e8d8585c3152a2da64b9076bd49ced1c4), in 2.2.0.1 stable) first tries `Uri.TryCreate(href, UriKind.Absolute)`. On Windows that fails for a path, and the path is read relative to the server. On Linux and macOS it succeeds, as an implicit file uri, and the `AbsolutePath` of that uri escapes the percent signs again:

| href | `IsFile` | `AbsolutePath` on Linux |
|---|---|---|
| `/dav/Duplicati/%23Photo/x.zip` | `true` | `/dav/Duplicati/%2523Photo/x.zip` |
| `/remote.php/dav/files/u/My%20Folder/x.zip` | `true` | `/remote.php/dav/files/u/My%2520Folder/x.zip` |
| `/plain/Folder/x.zip` | `true` | `/plain/Folder/x.zip` |

Decoded once, the path still has `%23Photo` or `%20`, so it does not start with the folder of the destination, and the whole path is taken as the file name. With `#` in the folder name this is the "Found 361 parse-able files with the prefix dav/Duplicati/%23Photo/duplicati" in the issue. Any escaped character in the folder path does the same, such as a space.

#6683 reports that WebDAV listings broke from 2.2.0.1 on Linux and not on Windows. It does not say what the folder is called, so it may or may not be the same problem.

## The change

An href that parses as a file uri is read relative to the server, as it is on Windows.

## Checked

`WebDavListNameTests` (new) answers a PROPFIND with a folder and one file in it, given by the path or by the full url, for the folder in the issue (`#Photo`), a folder with a space, and a plain folder. The test only looks at the files, because a full url also lists the folder itself as an entry, which is a separate matter.

| | Windows | Linux (WSL) |
|---|---|---|
| Before | 5 passed | 3 passed, 2 failed: the `#Photo` folder and the folder with a space, given by the path, listed as `dav/Duplicati/%23Photo/duplicati-…` and `remote.php/dav/files/user/My%20Folder/duplicati-…` |
| After | 5 passed | 5 passed |

The existing `WebDavRequestUrlTests` pass on both.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
