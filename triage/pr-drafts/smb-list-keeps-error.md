# SMB: report why a listing failed when closing the folder fails too

Branch: `fix/smb-list-keeps-error` (commit [affb0c03a9e7140e46e379a10754fc3534d51968](https://github.com/JamBalaya56562/duplicati/commit/affb0c03a9e7140e46e379a10754fc3534d51968)), based on master 7cdde158.

Related: https://forum.duplicati.com/t/22594 and `fix/smb-list-large-folder` (the two branches are independent of each other).

## Problem

`SMBShareConnection.ListAsync` closed the directory handle in a `finally` block. When the listing had already failed, an exception from that `CloseFile` replaced the original error. SMBLibrary throws `Not enough credits` from `CloseFile` when the listing request timed out and its credits have not come back, so users saw `Not enough credits` and not the real failure (`Failed to query directory contents with status STATUS_IO_TIMEOUT`).

## Change

When the listing fails, the handle is still closed, but a close failure is ignored and the original exception is rethrown. `PutAsync` already does the same. On success, the close status is checked as before.

## Testing

New unit test `SMBShareConnectionTests.ListReportsTheQueryStatusWhenCloseFails`. It drives `ListAsync` through a `DispatchProxy` `ISMBFileStore`: `QueryDirectory` returns `STATUS_IO_TIMEOUT`, and `CloseFile` throws `Not enough credits`, as SMBLibrary does. To make this possible, the `SMBShareConnection` constructor that takes a client and a file store is now `internal` (it was `private`). The test checks that the error names `STATUS_IO_TIMEOUT` and that the handle was closed.

- master: fails, because `System.Exception: Not enough credits` is thrown from `CloseFile` in `ListAsync`
- this branch: passes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
