Since #7642, `Utility.WithTimeout` stops waiting for a synchronous call when the timeout passes. The call itself keeps running, though, because a synchronous call cannot be stopped. For SMB and MEGA it also keeps using the connection that the next operation of the same backend gets.

Found while looking into [forum topic 22594](https://forum.duplicati.com/t/22594).

## SMB

- All calls in `SMBShareConnection` go through a helper. If the helper gives up on a call (timeout or cancellation), it disconnects the `SMB2Client` and marks the connection as broken.
  - SMBLibrary's `WaitForCommand` checks `m_clientSocket.Connected` every 100 ms, so closing the socket makes the abandoned call return.
  - The client allows only one request at a time, so a broken connection is never used again. Later calls on it throw without sending anything.
- Disposing a broken connection skips the tree disconnect and the logoff, and only closes the socket. Otherwise a server that stopped answering would make the dispose wait for the full response timeout twice.
- When the connection is broken, `ListAsync` does not close the directory handle. The handle went away with the connection, and the close would replace the `TimeoutException` with `STATUS_INVALID_SMB`.
- `CreateAsync` also disconnects the client if connecting, logging in or connecting to the share times out.
- `SMBBackend` disposes a broken connection and opens a new one on the next operation. `BackendManager` already discards a backend after a failure, but the BackendTool, the connection test and SMB sources keep using the same backend instance.

With this, `short-timeout`, `list-timeout` and `read-write-timeout` take effect for SMB. Before, a request to a server that stopped answering ended only when SMBLibrary's own response timeout ran out.

## MEGA

The MEGA client is shared by all operations of a backend instance, and a call that timed out keeps running on it.

- All five timed calls go through a helper. If the call times out, the helper drops the client, and the next operation logs in with a new one.
- Three of the calls are synchronous (`GetNodes()` twice, `Download(node)`). Two are asynchronous and ignore the token (`DeleteAsync`, `RenameAsync`), and time out since #7728.
- The client field is now typed as `IMegaApiClient`, and an internal `ClientFactory` lets the test supply the clients.

## Testing

New unit tests. They use no network: the SMB file store is a `DispatchProxy`, and `SMBBackend` takes an internal `ConnectionFactory`.

- `SMBTimeoutTests.TimedOutConnectionIsNotUsedAgain`: `ListAsync` with a `QueryDirectory` that never returns. It times out, the connection reports `IsBroken`, and the next call fails without opening anything on the file store.
- `SMBTimeoutTests.BackendReplacesATimedOutConnection`: the first listing times out on a connection that hangs. The second listing goes through a new connection and returns the file.
- `MegaClientTimeoutTests.TimedOutClientIsReplaced`: the first client's `GetNodes()` never returns, and `list-timeout` is 1 s. The first listing throws `TimeoutException`. The second listing goes through a new client and does not call the first client again. Without the helper, the second listing reused the stuck client and timed out again.

I also tried it against a real server: Samba 4.15.13 in Docker, a .NET 10 container on the same network, `list-timeout=2s`, and `docker pause` on the Samba container while a listing ran. The paused listing threw `TimeoutException` after 2.0 s, and the client's socket went from ESTABLISHED to FIN_WAIT2. After the server resumed, the next listing succeeded on a new connection (a new local port). This run was before #7642 was merged, so the branch then carried the same `WithTimeout` change itself. It was also merged with a change that I did not submit, which raised SMBLibrary's response timeout to 30 s. With only that change and not this one, the paused listing failed with `STATUS_IO_TIMEOUT` after 30.2 s and the connection stayed open. I have not repeated the Docker run on the current branch.

Run again after rebasing onto master [c16a28aa8](https://github.com/duplicati/duplicati/commit/c16a28aa8cfb8564fa23b9caa5499b33711aae80), in one build with the other branches I am opening today: 48 tests passed, among them `SMBTimeoutTests` and `MegaClientTimeoutTests`. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
