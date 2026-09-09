`--alternate-destination-marker` is only checked when `--alternate-target-paths` is also given (#1520). A share mounted on a folder that also exists when the share is not mounted can then be written to while unmounted, and the destination folder is created inside the empty mount point.

## The change

- The file backend now checks the marker when only `--alternate-destination-marker` is given. A destination without the marker, or one that does not exist, stops with `NoDestinationWithMarker` when the backend is created, so nothing is written there and no folder is created.
- With `--alternate-target-paths` it works as before.
- The help text no longer says that the marker needs `--alternate-target-paths`.

## Testing

New `FileBackendDestinationMarkerTests`, 4 tests. On master 2 of them fail (a marker alone accepts a destination without the marker, and one that does not exist). All 4 pass here. With `OptionsTests` and `OptionDescriptionFormatTests`, 31 tests pass. No new warnings in the changed files.

Not done: the documentation (`file-destination.md`) describes the marker only together with several destinations. I will add the single destination case there after this is merged.

Fixes #1520

🤖 Generated with [Claude Code](https://claude.com/claude-code)
