A restore to another folder skips links that point outside it. The check resolves a link's target from the link's parent, but a folder link's path ends in a separator, so the parent it takes is the link itself. A folder link pointing one level outside the restore folder is therefore made, while the same link to a file is skipped.

The check now gets the full path from `targetpath`, which has no trailing separator.

I found this while looking at #3271, which it does not fix.

## Testing

New `RestoreSymlinkOutsideTargetTests.LinksPointingOutsideTheRestoreFolderAreNotMadeAsync`, for both the new and the legacy restore. On Windows on the current master:

- Without the change, both fail: only the file link gets the `SymlinkTargetOutside` warning (`Expected: 2 But was: 1`).
- With the change, both pass.

No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
