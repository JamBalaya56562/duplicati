A sync skips a remote source given as `@mountpoint|url` with `SourceRootMissing` and copies nothing, although the source tests pass (#7783). Thanks to @freakstreet for the report and the analysis.

## Cause

On master I found five things, the first two from the report:

1. `SyncHandler` looks up each source root with `GetEntryAsync(src)`, where `src` is the whole declaration. That is not a path any provider knows, so the root is not found with any backend (also `file://`).
2. Even with the right path, the SSH backend cannot look up a single entry: `SSHv2Backend.GetEntryAsync` always returns `null`.
3. With several sources, the folder of each source on the destination is created only in snapshot mode. Without snapshots, even **two local sources** fail with `FolderMissingException`, as the folder loop lists the source folder before it exists. There was no sync test with more than one source.
4. With several sources, the folder of a remote source is named after the end of its declaration, so the URL query, credentials included, becomes a folder name (`snapshot-a?auth-username=user&auth-password=…`).
5. The `SourceRootMissing` warning shows the URL of a remote source with its credentials.

Fixing 1 and 2 showed one more: the file backend reports local times, and `BackendSourceFileEntry` passed them on as UTC. Outside UTC, every second sync of a remote source uploads every file again. This is likely why the report mentions running the tests with `TZ=UTC`.

## The change

- **Remote source root**: the root of a remote source is now the root of the provider mounted at its mount point, from `EnumerateAsync`. The backend is not asked to look up an entry. Local sources are looked up as before.
- **Several sources**: before the folder loop, the destination root is processed with the source roots as its only sub-folders. This creates the missing ones as any other sub-folder, and does not delete anything, so files and folders next to them are kept. Snapshot mode and `BlindlyUpload` already create their folders and are not changed.
- **Folder name**: `GetSourceRelativeRoot` names a remote source after its mount point. Snapshot mode uses the same function.
- **Warning**: the warning shows a remote source with `GetUrlWithoutCredentials`.
- **Times**: `BackendSourceFileEntry` converts a time of kind `Local` to UTC. Other times are kept as they are; the SSH backend already reports UTC.

I did not change `Combiner.GetEntryAsync`, which never asks a mounted provider (it checks its own `MountedPath`, which is always empty), as the backup also uses it.

This is different from the patch in the issue, which seeds the roots from `EnumerateAsync` of the combined provider. That provider can also list entries that are not source folders: with #7784 it also lists the parent folder of a file source.

## Testing

New `SyncRemoteSourceTests`, 7 tests:

| test | master | this branch |
|---|---|---|
| a remote source is synced, second run uploads nothing (`file://`, and a stub backend without entry lookup like SSH) | **fail** (2) | pass |
| several sources each get their own folder, a file next to them is kept (local + local, remote + local) | **fail** (2): `FolderMissingException` | pass |
| snapshot folders use the mount name of a remote source | **fail**: `IOException`, folder name with the query | pass |
| a warning for a remote source does not show its credentials | **fail** | pass |
| the times of a remote entry are in UTC | **fail**: `Local` | pass |

With only the time change reverted, 4 of them fail (the second runs upload 2 files again, in UTC+9).

`SyncHandlerTests`, `SyncCheckoutTest`, `BackendSourceProviderTests`, `ChangeTrackingSourceProviderTests`, `RemoteSourceDefaultExcludesTests`, `SourceProviderFactorySnapshotOwnershipTests`, `ProblematicPathTests` and `ParsingTests`: 114 pass, 5 skipped. No new warnings in the changed files.

I also synced from a real SFTP server (OpenSSH in a throwaway Debian container) to a local folder on Windows, twice for each of `UseRemoteState` and `UseLocalState`. The source had a nested folder, a file named `été.txt` and an empty file.

| | SFTP source only | SFTP + local source |
|---|---|---|
| master | `SourceRootMissing`, nothing copied, the warning shows the password | `FolderMissingException` (`UseRemoteState`) |
| this branch | first run 3 files with the content of the source, second run 0 uploads | `nas\` and `sftp-local\` folders, second run 0 uploads |

Note: I expect a backup of a remote source on a backend that reports local times (such as `file://`) to see the times of all files as changed once after this change. I did not try this.

Not tried: SMB, Linux and macOS.

Fixes #7783

🤖 Generated with [Claude Code](https://claude.com/claude-code)
