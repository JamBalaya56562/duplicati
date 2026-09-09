# SMB: close the file handle when get, delete or rename fails

Branch: `fix/smb-close-handle-on-failure` (commit [9863d4aa72d1e63ed73a3536c3cccd48e39c5b2f](https://github.com/JamBalaya56562/duplicati/commit/9863d4aa72d1e63ed73a3536c3cccd48e39c5b2f)), based on master 7cdde158.

Found while looking into https://forum.duplicati.com/t/22594. Related branches: `fix/smb-list-large-folder` and `fix/smb-list-keeps-error`.

## Problem

`SMBShareConnection.GetAsync`, `DeleteAsync` and `RenameAsync` open a file and close it only on the success path. If the read loop fails in `GetAsync` (a read error, a write timeout on the destination, or cancellation), or if `SetFileInformation` fails in `DeleteAsync` or `RenameAsync`, the exception is thrown before `CloseFile` runs. The handle then stays open on the server for as long as the shared connection lives. For delete and rename, the file was also opened with `ShareAccess.None`, which can block a retry on the same file.

## Change

On failure, each of the three methods now closes the handle, ignores any error from the close, and rethrows the original exception. `PutAsync` already does the same. The success path is unchanged.

## Testing

New unit tests in `SMBShareConnectionHandleTests` (`DeleteClosesTheFileWhenItFails`, `RenameClosesTheFileWhenItFails`, `GetClosesTheFileWhenItFails`). They use a `DispatchProxy` `ISMBFileStore` that opens any file, returns `STATUS_ACCESS_DENIED` from `ReadFile` and `SetFileInformation`, and counts calls to `CloseFile`. To make this possible, the `SMBShareConnection` constructor that takes a client and a file store is now `internal` (it was `private`).

- master: all 3 tests fail (`CloseFile` was called 0 times)
- this branch: all 3 tests pass

This branch merges cleanly with `fix/smb-list-keeps-error` and `fix/smb-list-large-folder`. I checked this with a temporary three-way `jj new` merge. `fix/smb-list-keeps-error` makes the same `private` → `internal` change to the constructor.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
