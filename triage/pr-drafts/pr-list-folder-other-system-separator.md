A backup keeps the paths of the system that made it. When a Linux backup is restored directly on Windows, or a Windows backup on Linux, the root of the backup is shown as a folder, but listing it returns `Success: true` with `Data: []` (duplicati/ngclient#449, [forum topic 22076](https://forum.duplicati.com/t/22076)). There are two causes, one for each direction.

## Linux backup on Windows

Since #7345, `ListFolderHandler` adds a trailing separator to the folder to list. It used `Util.AppendDirSeparator(path)`, which adds the separator of this system. So on Windows, the Linux folder `/source/` was looked up as `/source/\`, which is not a stored prefix.

The separator is now taken from the path with `Util.GuessDirSeparator`, as the database lookups of the same listing already do (`LocalListDatabase`).

## Windows backup on Linux

`LocalDatabase.SplitIntoPrefixAndName` splits a path into the folder it is in and its name, on `Path.DirectorySeparatorChar` and `Path.AltDirectorySeparatorChar`. On Linux both are `/`, so a Windows path such as `C:\source\Documents\` was not split at all. It was stored as a name with an empty prefix, and `C:\source\` had no entries. This was the case before #7345 as well.

A path is now split on the separators of the system it comes from:

- A path that starts with `/` is split on `/` only. A backslash is an ordinary character in a Unix name.
- Any other path is split on `\` and `/`.

A path from the same system is split as before: a Linux path on Linux, and a Windows path on Windows. On Windows, a Linux path is no longer split at a backslash in a name.

## Testing

- New `DirectListHandlerTests.ListFolder_BackupFromAnotherOperatingSystem_ListsTheEntriesOfAFolderAsync`. It makes a backup, rewrites the paths in its dlist to the form of the other system, deletes the database and rebuilds it with `repair-only-paths`, as a direct restore does. Then it lists the root with and without the trailing separator, and the folder below it.
- New `SplitIntoPrefixAndNameTests` (10 cases): Windows, UNC and Unix paths, and Unix names with a backslash.

| | master | this branch |
|---|---|---|
| Windows | the listing test fails (the root lists nothing), and 2 split cases fail (the Unix names with a backslash) | pass |
| Linux (WSL) | the listing test fails, and 3 split cases fail (the Windows and UNC paths) | pass |

With `DirectListHandlerTests`, `ListPrefixMultipleRootsTests`, `RestoreLargestPrefixTests` and the tests with `Recreate` in their name, 111 tests pass on both Windows and Linux. No new warnings in the changed files.

I also used the backups from the issue, made by 2.4.1.101 Canary on Linux and on Windows. I ran a server built from master and from this branch, on Windows and on Linux (WSL), with isolated data folders. The requests were the same as ngclient's: a temporary job (`POST /api/v1/backups?temporary=true`), `list-filesets`, `repairupdate` with `only_paths`, then `list-folder`.

| | master | this branch |
|---|---|---|
| Linux backup on Windows | the root `/fixture/linux-source/` lists `[]` | `Documents/` and `peer.txt`; `Documents/` lists `payload.txt` |
| Windows backup on Linux | the root `C:\...\windows-source\` lists `[]` | `Documents\` and `peer.txt`; `Documents\` lists `payload.txt` |
| the same system (both) | correct | the same |

A restore of `Documents` through `copytotemp`, as ngclient does it, restored only `payload.txt` in both directions, with the content of the source file.

## Not part of this change

Restoring with the same temporary job that was used for the listing fails with "Found 2 remote files that are not recorded in local storage", on the same system as well. The `only_paths` database has no record of the dblock and dindex files, so the remote list check before the restore (`FilelistProcessor.VerifyRemoteListAsync`) finds them extra. ngclient restores through `copytotemp`, so it does not hit this. A client that calls the API directly does, so this could be looked at separately.

Checked together with #7772 and #7775 in one temporary merge: no conflict, it builds, and the tests of all three pass (53 tests).

Refs duplicati/ngclient#449

🤖 Generated with [Claude Code](https://claude.com/claude-code)
