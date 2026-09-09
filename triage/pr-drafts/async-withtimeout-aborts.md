# WithTimeout: stop waiting for async calls that ignore the token

Branch: `fix/async-withtimeout-aborts` (commit [0b3207cb0b0b90315a5c7baddf069a0d30fdbc82](https://github.com/JamBalaya56562/duplicati/commit/0b3207cb0b0b90315a5c7baddf069a0d30fdbc82)), based on master 922a7c73.

Related: `fix/smb-timeout-aborts` (the same change for the synchronous overloads), `fix/withtimeout-cancel-vs-timeout`.

## Problem

The async overloads of `Utility.WithTimeout` awaited `func(cts.Token)` directly. The timeout only took effect if the call honored the token. Several libraries take no token at all, so their calls had no timeout (I checked the APIs with reflection):

- **Mega** (MegaApiClient 1.10.4): `GetNodesAsync`, `DeleteAsync` and `RenameAsync` take no token.
- **Storj** (uplink.NET 2.14): `EnsureBucketAsync`, `DeleteObjectAsync`, `DownloadObjectAsync`, `ListObjectsAsync`, `UploadObjectAsync` and `CopyObjectAsync` take no token.
- **SharePoint** (CSOM): `ExecuteQueryAsync()` takes no token.

The call sites pass `_ =>` and ignore the token, so a server that stopped answering kept the operation waiting regardless of `short-timeout`, `list-timeout` or `read-write-timeout`.

## Change

- **Utility:** both async overloads now await `func(cts.Token).WaitAsync(cts.Token)`.
  - A call that honors the token behaves as before: it is cancelled and the overload returns.
  - A call that ignores the token is no longer waited for after the timeout, but keeps running in the background.
- **SharePoint:** a `ClientContext` is not thread safe, and a query that timed out keeps running on it. All timed `ExecuteQueryAsync` calls now go through `ExecuteQueryWithTimeoutAsync`, which stops handing out the context after a timeout, so the next operation creates a new one.
  - Most operations already retry once with a new context after any failure. The exception is an upload that has already started: `DoPutAsync` disables its retry there, so the old context stayed in `m_spContext`.
  - The delete call's `Recycle()`/`DeleteObject()` only add to the pending query, so they now run before the timed call instead of inside it.
- **Mega:** the mitigation (drop a client whose call timed out) is in `fix/smb-timeout-aborts`. It covers the synchronous and asynchronous Mega calls together, so this branch does not touch `MegaBackend.cs`. The asynchronous Mega calls only time out once both branches are in.
- **Storj:** no mitigation. The calls that are left running end on their own, and uplink can be used from several calls at once. `BackendManager` also discards a backend after a failed operation.

For seams, `SharePointBackend` gets an internal `ContextFactory`, and `GetSpClientContextAsync` and `WrappedExecuteQueryOnContextAsync` become internal. The unit test project references `SharePointPnP.Client.dll`, because the backend references it directly and the reference does not flow to the tests.

## Testing

New unit tests in `AsyncWithTimeoutAbortTests`:

- `AsyncCallThatIgnoresTheTokenTimesOut`, `AsyncCallWithResultThatIgnoresTheTokenTimesOut`: a call that waits on another token, with a 1 s timeout. On master, both had not returned after 10 s (fail). On this branch, both throw `TimeoutException` (pass).
- `SharePointDoesNotReuseAContextWhoseQueryTimedOut`: a `ClientContext` subclass whose `ExecuteQueryAsync()` never completes. After `WrappedExecuteQueryOnContextAsync` times out, the next `GetSpClientContextAsync(false)` must return a different context.
  - Without the two lines that drop the context, it got the same context again (fail).
  - With them, the test passes.

To check that calls that honor the token are unaffected, I ran the existing offline backend and retry tests on this branch: Jottacloud (including `JottacloudStalledResponseTests`), Google Drive, pCloud, Box, S3 point-in-time, Duplicati backend, iDrive e2, Drime and Filejump delete retry, and `MissingDestinationRetryTests`, together with the new tests. All 129 passed.

This branch merges cleanly with `fix/smb-timeout-aborts`, `fix/withtimeout-cancel-vs-timeout` and `fix/with-per-item-timeout`, which also edit `Utility.cs`. I checked this with a temporary four-way `jj new` merge, and the tests of all four branches pass on the merged tree.

## Not covered

`UploadFileSlicePerSlice` in the SharePoint backend calls `ctx.ExecuteQueryAsync()` for each chunk without any `WithTimeout`. Only the stream it reads has a timeout. This is unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
