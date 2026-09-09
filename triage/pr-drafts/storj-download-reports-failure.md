Branch: `fix/storj-download-reports-failure` (fork), **stacked on `fix/storj-transfer-timeout`** ([3f41670f91e5a7ba9df86b594620f8507f5abdbe](https://github.com/JamBalaya56562/duplicati/commit/3f41670f91e5a7ba9df86b594620f8507f5abdbe)), because it changes the lines right after `WaitForTransferAsync`. Open it only after `fix/storj-transfer-timeout` is merged, rebased onto master.

---

Report failed Storj downloads as errors

## Summary

uplink.NET reports a download that fails part way through (an error from `uplink_download_read` or `uplink_close_download`) by setting `Failed` and `ErrorMessage` on the `DownloadOperation`; the task returned by `StartDownloadAsync` still completes successfully. If the download could not be opened at all, the operation is already `Failed` and `StartDownloadAsync` returns no task. Neither `GetAsync` overload checked this:

- `GetAsync(remotename, Stream)` returned normally after writing only the bytes received so far.
- `GetAsync(remotename, filename)` wrote nothing unless the download completed, and returned normally either way.

What happens next depends on the caller:

- `BackendManager` (backup, restore, verify): the size check in `GetOperation.ExecuteAsync` usually catches the short file and throws "downloaded file size … expected …", which is retried, but the real Storj error is lost, the parity repair is tried on a truncated file, and with `--skip-file-hash-checks` (or no known size or hash) the truncated file is accepted.
- `LightWeightBackendManager` (remote synchronization): there is no size or hash check on download, so a truncated source file is copied to the destination as if it were complete (the optional get-after-put check hashes the truncated temp file, so it does not notice).

Both overloads now throw `new Exception(download.ErrorMessage)` when the download did not complete, the same as `PutAsync` already does for `upload.Failed`, so a failed download is retried by the backend manager like any other backend error.

An internal constructor that takes the uplink.NET services lets the tests run the backend without the native library.

## Testing

New `StorjDownloadFailureTests` run `Storj.GetAsync` with uplink.NET's own `DownloadOperation` objects, created without their constructor (so no native code runs) and driven through the same fields and progress event that uplink.NET uses:

| Test | Before | After |
| --- | --- | --- |
| Download to a stream fails after 400 of 1000 bytes | no exception, 400 bytes written | throws with the uplink.NET error |
| Download to a file fails after 400 bytes | no exception | throws with the uplink.NET error |
| Download failed before it started (no task) | no exception | throws with the uplink.NET error |
| Download to a stream / file completes | all bytes | all bytes |

`StorjDownloadFailureTests` + `StorjTransferTimeoutTests` + `StorjUploadOptionsTests`: 13/13 pass locally on Windows. No build warnings in the Storj project or the new test file.

Commit: [1be83e25913f9173eb5dc47717d151dd4c2d400d](https://github.com/JamBalaya56562/duplicati/commit/1be83e25913f9173eb5dc47717d151dd4c2d400d)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
