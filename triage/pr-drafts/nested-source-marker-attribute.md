## What happens

When one source sits inside another, the inner source is taken out of the source list. This assumes the walk of the outer source reaches it. [990bbf6297d618e4b810d5062a0a35d096727e3f](https://github.com/duplicati/duplicati/commit/990bbf6297d618e4b810d5062a0a35d096727e3f) keeps the inner source when a folder on the way is excluded by the filter. But the walk also stops at other folders, and those were not considered:

- a folder holding an ignore marker (`--ignore-filenames`, `CACHEDIR.TAG` by default)
- a folder whose attributes are excluded (`--exclude-files-attributes`)
- a folder that an extended attribute marks as excluded from backups (`user.duplicati.exclude`, or `com_apple_backup_excludeItem` on macOS)
- a symbolic link that is not followed (`--symlink-policy=ignore`, or `store`, the default)

So the inner source was dropped, and the files below it were missing from the backup, with no warning and no error. Named on its own, the same folder is backed up, because a root entry is never excluded.

This happens even with no options set. With sources `<data>` and `<data>/cache/wanted/`, and `<data>/cache` holding `CACHEDIR.TAG`, the backup keeps only the file outside `cache`.

The enumeration checks all of these before the filter or regardless of it (`SourceFileEntryFilterAsync`). So the include filter that replaces a removed source cannot bring it back. This applies to the inner source itself too, not only to the folders above it.

## The change

`IsCutOffByFilter` becomes `WalkTowards`. It follows the checks the enumeration makes, in the same order, for every folder between the two sources and for the inner source itself:

1. ignore marker
2. attributes
3. filter
4. the exclusion extended attribute, unless `--disable-backup-exclusion-xattr` is set
5. symbolic links

Like the enumeration, it does not leave out a path whose attributes cannot be read.

- **Excluded** (by a marker, an attribute, the filter, the extended attribute, or an ignored link): the inner source is kept, as it already was for the filter.
- **Reached** (the walk gets to it): the inner source is removed as before, so nothing is walked twice.
- **Behind a link stored as a link** (`store`, the default): the inner source is not kept. It is left out as before, but now with a warning (`NestedSourceBehindStoredSymlink`). The warning names the link and suggests `--symlink-policy=follow`. If another source reaches the inner source, that still takes precedence.

The check now runs before the filter branch. Before, an inner source was removed without any check when there was no filter.

### Why a stored link is not kept

A test hook forced the inner source to be kept. Measured on Linux, and on Windows with both symbolic links and junctions:

- When the inner source is the link itself, the backup fails with `UNIQUE constraint failed: FilesetEntry.FilesetID, FilesetEntry.FileID`. The link and the folder are recorded under the same path.
- When the link is on the way to the inner source, the backup works. But it records the link and a folder below the same path. A restore to the original location, with the link gone, then goes wrong:
  - On Linux, the restored files are deleted. `FileRestoreDestinationProvider.WriteMetadata` removes the folder to create the link.
  - On Windows, the folder stays and the link is not created.

For extended attributes and ignored links, the same hook gave the same files as naming the source on its own. That held over two backups, with no error or warning, and a restore put the files back.

## Checked

`NestedSourceExclusionTests` gets thirteen new tests. The table shows each test's result before and after the change:

| Test | Before | After |
|---|---|---|
| `ASourceInsideAFolderWithAnIgnoreMarkerIsStillBackedUp` | fails (Win, Linux) | passes |
| `ASourceInsideAFolderWithAnIgnoreMarkerIsStillBackedUpWithAnUnrelatedExclude` | fails (Win, Linux) | passes |
| `ASourceInsideAFolderWithExcludedAttributesIsStillBackedUp` | fails (Win, Linux) | passes |
| `ANestedSourceWithExcludedAttributesIsStillBackedUp` | fails (Win, Linux) | passes |
| `ASourceInsideAFolderExcludedByAnExtendedAttributeIsStillBackedUp` | fails (Linux) | passes |
| `ANestedSourceExcludedByAnExtendedAttributeIsStillBackedUp` | fails (Linux) | passes |
| `ASourceBehindAnIgnoredSymlinkIsStillBackedUp` | fails (Win, Linux) | passes |
| `AnIgnoredSymlinkNamedAsANestedSourceIsStillBackedUp` | fails (Win, Linux) | passes |
| `ASourceBehindAStoredSymlinkIsLeftOutWithAWarning` | fails, no warning (Win, Linux) | passes |
| `AStoredSymlinkNamedAsANestedSourceIsLeftOutWithAWarning` | fails, no warning (Win, Linux) | passes |
| `AFolderWithExcludedAttributesAndNoSourceInsideStaysExcluded` | passes | passes |
| `ANestedSourceIsStillCoveredWhenTheExtendedAttributeIsNotHonoured` | passes | passes |
| `ASourceBehindAFollowedSymlinkIsStillCovered` | passes | passes |

Notes on these results:

- The extended attribute tests set the attribute with the Linux call, so they are skipped on other systems.
- The symbolic link tests are skipped where links cannot be created.
- The "before" failures for the four ignore-marker and attribute tests are against master. The other "before" failures are against the first commit of this branch.

The rest of `NestedSourceExclusionTests`, and all of `SourcePathExpansionTests`, pass before and after. Most backups go through `TestUtils.AssertResults`, which fails on any warning or error, so a tree walked twice would show up. The two stored-link tests expect a warning instead, and check that there is no error.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
