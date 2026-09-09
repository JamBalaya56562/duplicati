# SMB: stop waiting for timed-out calls, and replace the connection

Branch: `fix/smb-timeout-aborts` (commit [17b516e65c7fbbd18b7f83d63e73f764d04ccdde](https://github.com/JamBalaya56562/duplicati/commit/17b516e65c7fbbd18b7f83d63e73f764d04ccdde)), based on master 922a7c73.

Found while looking into https://forum.duplicati.com/t/22594. Related branches: `fix/smb-list-large-folder`, `fix/smb-list-keeps-error`, `fix/smb-close-handle-on-failure`.

## Problem

The synchronous overloads of `Utility.WithTimeout` (`Action<CancellationToken>` and `Func<CancellationToken, T>`) awaited `Task.Run(() => func(ct), ct)`. That token only stops a task that has not started yet. Once the call is running, the timeout has no effect and the overload waits for the call to finish. As a result, `short-timeout`, `list-timeout` and `read-write-timeout` never took effect for SMB. SMB requests ended only when SMBLibrary's own response timeout ran out.

28 call sites use the synchronous overloads. I found them by marking both overloads `[Obsolete]`, building `Duplicati.slnx` with `--no-incremental`, and collecting the CS0618 warnings from a file logger:

- SMB (10): the calls in `SMBShareConnection`, handled here
- File (4), Mega (3), SSHv2 `GetAttributes` (1), TencentCOS (3), B2AuthHelper (1): synchronous library or IO calls. With this change they also stop being waited for when the timeout passes, and the call finishes in the background. None of these share a connection the way SMB does, except the Mega client. `BackendManager` discards a backend after a failed operation, so a later operation gets a new client.
- Filejump (1): `HttpClient.Send(request, ct)` honors the token, so it is already stopped by the timeout.
- `S3MinioClient.cs:115`, SSHv2 `ListDirectoryAsync` (2), and `Utility.WithPerItemTimeout` (1): these only create an observable, an async enumerable or an enumerator, and return at once, so this change does not affect them. (The listings they start were not covered by the timeout at all; see `fix/s3-minio-list-timeout` and `fix/ssh-list-timeout`.)
- SSHv2 rename (1): resolved to the synchronous overload by mistake; see `fix/ssh-rename-awaited`.

All other call sites (about 200) use the async overloads.

## Change

- **Utility:** the two synchronous overloads now await `Task.Run(...).WaitAsync(cts.Token)`. When the timeout passes they throw `TimeoutException` and stop waiting. The call itself keeps running, because a synchronous call cannot be stopped.
- **`SMBShareConnection`:**
  - All calls now go through a helper. If that helper gives up on a call (timeout or cancellation), it disconnects the `SMB2Client` and marks the connection as broken.
  - SMBLibrary's `WaitForCommand` checks `m_clientSocket.Connected` every 100 ms, so closing the socket makes the abandoned call return. The client allows only one request at a time, so the connection is never used again: later calls throw without sending anything.
  - Disposing a broken connection skips the tree disconnect and the logoff, and only closes the socket. A server that stopped answering would otherwise make the dispose wait for the full response timeout twice.
  - When a connection is broken, `ListAsync` skips closing the directory handle. The handle went away with the connection, and the close would otherwise replace the `TimeoutException` with `STATUS_INVALID_SMB`.
  - `CreateAsync` also disconnects the client if connecting, logging in or connecting to the share times out.
- **`SMBBackend`:** a broken shared connection is disposed and replaced on the next operation. `BackendManager` already discards a backend after a failure, but the BackendTool, the connection test and SMB sources keep using the same backend instance.
- **`MegaBackend`:** the MEGA client is shared by all operations of a backend instance, and a call that timed out keeps running on it. All five timed calls now go through a helper. If the call times out, the helper drops the client, and the next operation logs in with a new one.
  - Three of the calls are synchronous (`GetNodes()` twice, `Download(node)`), so they only time out with this change.
  - Two are asynchronous and ignore the token (`DeleteAsync`, `RenameAsync`), so they only time out with `fix/async-withtimeout-aborts`.
  - The helper is placed here so that the Mega mitigation lives in one branch, and `fix/async-withtimeout-aborts` does not touch `MegaBackend.cs`.
  - The client field is now typed as `IMegaApiClient`, and an internal `ClientFactory` lets the test supply the clients.

**Interaction with `fix/smb-list-large-folder`:** that branch sets SMBLibrary's response timeout to the largest of the three timeouts. On its own, that makes every request to a server that stopped answering wait up to `list-timeout` (10 minutes by default). With this change, each operation stops at its own timeout (for example `short-timeout`, 30 s), so that longer wait goes away.

## Testing

New unit tests in `SMBTimeoutTests`. They use no network: the file store is a `DispatchProxy`, and `SMBBackend` takes an internal `ConnectionFactory`.

- `WithTimeoutStopsWaitingForAnAction`, `WithTimeoutStopsWaitingForAFunction`: a 1 s timeout around a call that never returns
- `TimedOutConnectionIsNotUsedAgain`: `ListAsync` with a `QueryDirectory` that never returns. It times out, the connection reports `IsBroken`, and the next call fails without opening anything on the file store.
- `BackendReplacesATimedOutConnection`: the first listing times out on a connection that hangs. The second listing goes through a new connection and returns the file.

On master, all 4 tests fail: the call is still running after 10 s. On this branch, all 4 pass.

- `MegaClientTimeoutTests.TimedOutClientIsReplaced`: the first client's `GetNodes()` never returns, and `list-timeout` is 1 s. The first listing must throw `TimeoutException`, and the second listing must go through a new client and must not call the first client again.
  - Without the helper (but with the rest of this branch), the second listing reused the stuck client and timed out again, so the test failed.
  - With the helper, the test passes.

I also tested against a real server: Samba 4.15.13 in Docker, a .NET 10 container on the same network, `list-timeout=2s`, and `docker pause` on the Samba container while a listing ran. Logs: `smb-timeout-aborts-docker-red.txt` and `smb-timeout-aborts-docker-green.txt` in the session notes.

- `fix/smb-list-large-folder` alone, where SMBLibrary waits 30 s: the paused listing failed with `STATUS_IO_TIMEOUT` after 30.2 s, and the connection stayed open.
- `fix/smb-list-large-folder` merged with this branch: the paused listing threw `TimeoutException` after 2.0 s. The client's socket went from ESTABLISHED to FIN_WAIT2, so the client had closed it. After the server resumed, the next listing succeeded on a new connection (a new local port).

## Merging with the other SMB branches

I checked each pair with a temporary `jj new` merge:

- `fix/smb-close-handle-on-failure`: merges cleanly.
- `fix/smb-list-large-folder`: conflicts in `CreateAsync`, because the two branches change adjacent lines. To resolve it, keep that branch's `responseTimeout` and `new SMB2Client(...)` lines, and call `WithTimeoutAsync(client, ...)` for `Connect`. Also drop the last sentence of its comment ("WithTimeout cannot stop a synchronous call ..."), which is no longer true once this change is in. I built and ran the Docker test above on that resolution.
- `fix/smb-list-keeps-error`: conflicts in the error path of `ListAsync`. To resolve it, keep that branch's `catch` block and add the broken check to it: `if (directoryHandle != null && !_broken)`.

## Not covered

The async overloads of `WithTimeout` still wait for a `func` that ignores the token; see `fix/async-withtimeout-aborts`. The async overloads also map only `TaskCanceledException` to `TimeoutException`; see `fix/withtimeout-cancel-vs-timeout`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
