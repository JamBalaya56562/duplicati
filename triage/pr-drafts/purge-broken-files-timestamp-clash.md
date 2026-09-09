# Keep purge-broken-files from breaking the database on a timestamp clash

A purged fileset gets a new filelist name, starting one second after its old one, and every replaced name stays registered. When filesets are seconds apart, or after a few purges of the same fileset, the next free second is at or after the following fileset, and the purge stops with `Unable to create a new fileset for ... because the resulting timestamp ... is larger than the next timestamp ...`.

For `purge-broken-files` this is worse than a failed purge. By the time a fileset is rewritten, the blocks of the missing volumes have already been dropped from the database and committed. So the broken files in the filesets that were not rewritten yet are left without their blocks. From then on, `backup`, `repair` and `test` stop with `Found inconsistency in the following files while validating database`, and `purge-broken-files` stops at the same fileset with the same timestamp error, so there is no way out short of recreating the database. This is the loop reported in #4923 (ts678 found the timestamp cause there), and in the forum thread "Repairing corrupted/broken backup job" (2.2.0.3).

Reproduction on current master (31bf7aa0225f095de70020700224d3f229dcfe65), with the CLI:

```
backup (11:46:13), backup (11:46:15)
purge --version=1 *dummy0.bin   -> version 1 moves to 11:46:14
purge --version=1 *dummy1.bin   -> fails: resulting timestamp 11:46:16 is larger than the next timestamp 11:46:15
delete one dblock file from the destination
purge-broken-files              -> fails with the same timestamp error
backup                          -> Found inconsistency in the following files while validating database
repair                          -> Found inconsistency ...
purge-broken-files              -> the same timestamp error
```

## Changes

- When the seconds after the original time up to the next fileset are taken, a free second before it (and after the previous fileset) is used instead. When one purge rewrites several filesets, the new times of the rewritten ones are used as the bounds for the next.
- `purge-broken-files` checks that every fileset it will rewrite can get a timestamp, in the order it rewrites them, before it commits anything. If one cannot, it stops with `NoUnusedFilesetTimestamp`, and the database is left as it was.

A fileset can now end up a few seconds before its original time. The order of the versions is kept.

## Testing

- New `PurgeFilesetTimestampTests`. The filesets are moved to fixed times, one or two seconds apart, by renaming them in the database and the destination.
  - `PurgeMovesAFilesetBackWhenTheNextSecondIsTakenAsync`, and `PurgeBrokenFilesHandlesFilesetsOneSecondApartAsync` (purge-broken-files, then backup and `test all`): fail without the earlier-second search, pass with it.
  - `PurgeBrokenFilesChangesNothingWhenAFilesetCannotGetATimestampAsync`: three filesets one second apart, so the middle one cannot move. Without the check, the backup after putting the volume back fails with `DatabaseInconsistencyException`. With it, purge-broken-files stops with `NoUnusedFilesetTimestamp`, and the backup and `test all` pass.
  - Four unit cases for the time search.
- The reproduction above, with the CLI built from this branch: every purge succeeds (the fileset moves back a second each time), and so do `purge-broken-files`, the backup, `repair` and `purge-broken-files` again.
- The existing purge and repair tests (`PurgeTesting`, `Issue6070`, `Issue6366`, `Issue6425`, `DryRunTests`, `RepairHandlerTests`, `RepairWithMissingRemoteFiles`, `ZeroLengthMetadataTests`, `DlistFilesetTimeTests`, `RepairFilesetTimestampTests`, `ProbeUnusedFilenameTests`): 91 passed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
