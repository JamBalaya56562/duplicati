Title: Find entries of a mounted source in a combined source

`Combiner.GetEntryAsync` never looked at the mounted providers. Its condition checked the combiner's own `MountedPath`, which is always empty, and compared the other way round (`provider.MountedPath.StartsWith(path)`). A path below a mount point therefore went to the local source and was not found. With a remote source next to a local one, `--changed-files` with a remote file had no effect, and the file kept its old content in the new version.

## The change

The path is given to the provider whose mount point it starts with. Both have a directory separator added, the comparison uses `ClientFilenameStringComparison`, and the longest mount point wins. The provider gets the path spelled with its own mount point.

## Testing

New `CombinerMountedEntryTests`, 3 tests:
- In a combiner with `music` and `music2` mounted, a path below each is found by the right provider.
- A backup of a local folder and a remote source with `--changed-files` set to a changed remote file picks up the change, and a restore gives the new content.
- A symbolic link entry is resolved the same way.

Before the change, the first two fail (no entry, `ModifiedFiles` 0). All 3 pass on Windows and Linux.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
