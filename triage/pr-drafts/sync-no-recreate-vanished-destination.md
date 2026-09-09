# Do not recreate a synchronization destination that disappears

The remote synchronization tool uses `LightWeightBackendManager`. It creates a missing destination folder (`--auto-create-folders`, on by default) only if nothing has been uploaded or downloaded yet, but a listing did not count.

The tool lists the destination before it copies to it. When the folder disappears after the listing, for example because a drive is unplugged, the next copy fails with `FolderMissingException`. The manager then creates the folder again, and the tool carries on into a new, empty folder in its place.

With this change, a listing that found files also counts, as it does for the main backend manager in #<the backup PR>. `ResetAsync` clears the new flag along with the others. The source manager never creates folders, so this only affects the destination.

## Testing

- New `LightWeightVanishingDestinationTests`:
  - `ADestinationThatDisappearsAfterItWasListedIsNotCreatedAgainAsync`: lists a destination with one file, moves the folder away, then puts a file. On master the folder is created again (red); with the change the put fails and the folder stays gone.
  - `AMissingDestinationIsStillCreatedAsync`: a destination that is not there to begin with is still created. Passes on master and with the change.
- `ToolTests`, which covers the synchronization tool: 41 passed, including the new ones.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
