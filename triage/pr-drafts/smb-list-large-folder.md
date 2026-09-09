# Wait for SMB responses as long as the configured timeouts

Branch: `fix/smb-list-large-folder` (commit [b8ee868abeb86ccc11f2399bf4d7f2fed07a8084](https://github.com/JamBalaya56562/duplicati/commit/b8ee868abeb86ccc11f2399bf4d7f2fed07a8084)), based on master 7cdde158.

Reported on the forum: https://forum.duplicati.com/t/22594 (listing a folder with ~20,000 files fails with `Not enough credits`).

## Cause

`SMBShareConnection.CreateAsync` built the `SMB2Client` with SMBLibrary's default response timeout of 5 seconds. SMBLibrary waits that long for each response, so when one page of a directory listing (up to 1 MiB) takes longer, `QueryDirectory` returns `STATUS_IO_TIMEOUT` even though `list-timeout` defaults to 10 minutes. The request's 16 credits are only returned when the late response arrives, so the `CloseFile` in the `finally` block of `ListAsync` runs with no credits left, throws `Not enough credits`, and hides the timeout.

## Change

- The SMBLibrary response timeout is now the largest of `short-timeout`, `list-timeout` and `read-write-timeout`.

**Behaviour change:** if the server stops responding, any SMB request, including short ones such as a delete, now waits up to the largest of these timeouts before it fails. With the defaults that is `list-timeout` (10 minutes), where it used to be 5 seconds. `Utility.WithTimeout` does not limit this, because it wraps the synchronous SMBLibrary calls in `Task.Run(..., token)`: once a call has started, it does not end when the timeout passes. In a unit test with `list-timeout=1s` and a `QueryDirectory` that never returned, `ListAsync` did not return for more than two hours. So the SMBLibrary response timeout is the only limit on an SMB request, both before and after this change. Users who want SMB requests to fail sooner can lower `--list-timeout`.

`fix/smb-timeout-aborts` (a separate PR) removes this longer wait. It makes the synchronous `WithTimeout` overloads stop waiting when the timeout passes. SMB then disconnects the client and replaces the connection, so each operation stops at its own timeout (for example `short-timeout`, 30 s). The two branches conflict on adjacent lines in `CreateAsync`. The resolution is described in that PR, and it removes the last sentence of the comment added here.
- New live test `SMBTests.TestSmbListLargeFolderOnSlowLink`: it creates 20,000 files on the Samba share and limits the container's outgoing bandwidth to 1 Mbit/s with `tc`, so a single listing page takes longer than 5 seconds. Then it lists the folder through `SMBBackend`. To make this possible, `RunSmbTest` now takes optional setup commands (the container runs privileged when they are given) and an optional check that replaces the BackendTester run.

## Testing

I ran Samba 4.15.13 (ubuntu:22.04) in Docker with 20,000 empty files and a 1 Mbit/s `tbf` limit on the server's egress, then ran `BackendTool LIST` from a .NET 10 runtime container on the same network:

- master: `Command failed: Not enough credits`, thrown from `SMB2FileStore.CloseFile` in `SMBShareConnection.ListAsync`
- this branch: all 20,000 files listed (54 s)
- without the bandwidth limit both builds list all 20,000 files, so folder size alone is not enough to trigger the failure

I could not run the new live test locally because the host's port 445 is taken by Windows, and could not run it on the fork's CI because Actions is disabled there. The CIFS job on this PR will be its first run.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
