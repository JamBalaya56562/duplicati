Fixes #3870

## What happens

A directory junction is restored as a directory symbolic link. I measured this with a junction made by `mklink /J`: it came back with reparse tag `0xA000000C` (`IO_REPARSE_TAG_SYMLINK`) instead of `0xA0000003` (`IO_REPARSE_TAG_MOUNT_POINT`).

Both are reparse points with a target, and Duplicati treats every reparse point with a target as a symbolic link:

- the backup keeps only the target (`CoreSymlinkTarget`)
- the restore makes a link with `Directory.CreateSymbolicLink`

The two are not interchangeable:

- Windows puts junctions in user profiles, such as "My Documents".
- A symbolic link needs a privilege or developer mode to make; a junction needs neither.

## The change

- **Backup:** for a link whose reparse tag is `IO_REPARSE_TAG_MOUNT_POINT`, the backup also records `CoreSymlinkType=junction`. The tag is read with `FindFirstFileW`.
- **Restore:** on Windows, when that is recorded, the restore makes a junction. .NET has no call for this, so `SystemIOWindows.CreateJunction` sets the mount point reparse data with `FSCTL_SET_REPARSE_POINT`.
- **Link already in place:** it is kept only when it is also of the right kind, so a symbolic link to the same place is replaced by the junction. That check comes from #7397.

A source that is itself a junction is recorded the same way, so it is restored as a junction too. Its files are restored through it first.

Backups made before this change have no kind recorded, and restore as before. On other systems, a junction is still made as a symbolic link.

### Attributes and permissions

The issue also reports that the junction loses its hidden attribute and its deny permission. These come back with `--restore-symlink-metadata` and `--restore-permissions`, as for any link, and they are set on the junction itself, not on the folder it points to.

Measured with a hidden junction that denies Everyone listing it (`Everyone:(DENY)(RD)`, as in a user profile):

| Restore options | Hidden | Deny on the junction | Folder it points to |
|---|---|---|---|
| none | no | no | unchanged |
| `--restore-symlink-metadata` | yes | no | unchanged |
| `--restore-symlink-metadata --restore-permissions` | yes | yes | unchanged |

Without the options, neither comes back. That is the same as for any other file, since permissions are only restored on request.

## Checked

`RestoreJunctionTests` (Windows only), before and after:

| Test | Before | After |
|---|---|---|
| `AJunctionIsRestoredAsAJunction` | fails, tag `0xA000000C` | passes |
| `ASymbolicLinkInPlaceOfAJunctionIsReplacedByTheJunction` | fails, tag `0xA000000C` | passes |
| `TheAttributesAndPermissionsOfAJunctionAreRestoredWhenAskedFor` | fails, tag `0xA000000C` | passes |
| `ASourceThatIsAJunctionIsRestoredAsAJunction` | fails, tag `0xA000000C` | passes |
| `AJunctionThatIsStillThereStaysAJunction` | passes | passes |
| `ASymbolicLinkToAFolderIsStillRestoredAsASymbolicLink` | passes | passes |

About the tests:

- They read the reparse tag with their own `FindFirstFileW` call, not the product's.
- They make the junction with `mklink /J`.
- They read the junction's own permissions with `icacls /L`.

These existing test classes pass on Windows:

- `RestoreSymlinkOverExistingDataTests`
- `SymLinkTests`
- `RestorePathTraversalTests`
- `AlternateDataStreamTests`
- `RestoreCallbackModuleTests`
- `BackupExclusionAttributeTests`

On Linux, the build passes and the same classes pass. The junction tests are skipped there.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
