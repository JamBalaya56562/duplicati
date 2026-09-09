With a SMB share as a remote source, the `$RECYCLE.BIN` and `System Volume Information` folders at the root of the share were backed up, although the default excludes were selected. Reported on the forum: https://forum.duplicati.com/t/root-of-remote-source-for-absolute-path/22900

- The Windows entries of the default excludes, such as `?:\$Recycle.Bin\`, only match at the root of a drive (`FilterGroups.cs`).
- A remote source is mounted below a folder, such as `X:\dupl-smb-xxxx\`, instead of on a drive, so these entries never reach the root of the share.
- `{DefaultExcludes}` is expanded into its entries when the filter is made, so the group itself cannot be recognized later.

## The change

`SourceProviderFactory.AddDriveRootEntriesForRemoteSources` is called from `Controller.ExpandInputSources`, which backup and sync both use. For each filter entry that starts with `?:\` or `?:/`, and for each remote source, the entry is added again with the mount point in place of the drive. It is added right after the original entry and with its sign, so the filter keeps its order.

- Entries that a user writes with `?:\` are treated the same way: they name the root of any drive, so also the root of the share.
- Folders of the same name deeper in the share are not affected.
- A mount point with a wildcard character is skipped, as the added entries would then match more than the share.
- Without a remote source, the filter is not changed.

## Testing

New `RemoteSourceDefaultExcludesTests`:

| test | master | this branch |
|---|---|---|
| `TheDefaultExcludesApplyAtTheRootOfAShare("$RECYCLE.BIN")` | **fail** | pass |
| `TheDefaultExcludesApplyAtTheRootOfAShare("System Volume Information")` | **fail** | pass |
| `TheAddedEntriesKeepTheSignOfTheEntry` | **fail** | pass |
| `AFolderOfTheSameNameDeeperInTheShareIsKept` | pass | pass |
| `WithoutARemoteSourceTheFilterIsNotChanged` | pass | pass |

The master column was measured on master when the branch was written. Not tried with a backup of a real SMB share.

Rebased on master [d6dcdd0c7](https://github.com/duplicati/duplicati/commit/d6dcdd0c734f99d9c5101e55cd3dc287b191e5e9), on Windows: `RemoteSourceDefaultExcludesTests` and the other `RemoteSource*` tests, 9 passed. No warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
