Builds on #7364 and on the branch that releases the blocks of skipped files (`fix/restore-skipped-file-releases-blocks`), as it changes the same handlers. Open this after those are merged, rebased on master.

## What happens

A file the restore gives up on is added to `BrokenLocalFiles`. At the end, the restore reports that list as "Failed to restore N local files" with their paths. The handler for an empty file that cannot be created only logs an error, so the file is missing from that list. The same goes for a file whose block counts do not match.

## The change

- Both handlers now add the file to `BrokenLocalFiles`, under the same lock the other handlers use.
- The empty-file handler now lets a stop or an abort through, like the other per-file handlers. Otherwise an interrupted restore would list the file as failed.

## Red to green

`AnEmptyFileThatCannotBeCreatedIsReported` (new, in `RestoreFileFailureTests`): a folder sits where an empty file should go.

| | Before | After |
|---|---|---|
| The file is in `BrokenLocalFiles` | **red**: the list is empty | green |

Measured on Windows and on Linux (ext4, WSL). The other tests in the class and the related restore tests (19) pass.

## Not covered

- The block count mismatch path cannot be reached without an inconsistent verification, so it has no test.
- The stop/abort filter has no test of its own: the stop would have to land while the empty file is being created.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
