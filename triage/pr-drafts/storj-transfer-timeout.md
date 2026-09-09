Branch: `fix/storj-transfer-timeout` (fork), based on master `922a7c73`, independent of the other timeout branches (no shared files).

---

Time out Storj transfers that stop moving

## Summary

The Storj backend waits for a transfer with `await upload.StartUploadAsync()` / `await download.StartDownloadAsync()`. uplink.NET runs the transfer loop on its own thread (`Task.Run(DoUpload)` / `Task.Run(DoDownload)`) and takes no cancellation token, so nothing measures the calls into the native library that do the network work (`uplink_upload_write`, `uplink_upload_commit`, `uplink_download_read`, `uplink_close_download`).

The only timeouts on the path are the stream observers, and `TimeoutObservingStream` measures a single `Read`/`Write` call:

- upload: `ObserveReadTimeout` wraps the local source stream, not the network
- download to a stream: `ObserveWriteTimeout` wraps the local target stream, not the network
- download to a file: nothing at all

So an upload or download that stops moving on the network is waited for forever, and the cancellation token is not observed while the transfer runs either.

This change adds `WaitForTransferAsync`, which waits for the transfer task while polling the operation's byte count (`BytesSent` / `BytesReceived`). If the count has not moved for `read-write-timeout`, it throws `TimeoutException`; if the token is cancelled, it throws `OperationCanceledException`. In both cases it calls the operation's `Cancel()`, so uplink.NET aborts the upload (`uplink_upload_abort`, nothing is committed) or closes the download once the current native call returns, and the transfer is not waited for. A slow transfer that keeps moving is not cut off. A `read-write-timeout` of zero or infinite keeps the old behaviour (no timeout).

The byte count moves once per native call: 256 KiB for an upload, and at most a tenth of the object for a download (uplink.NET's chunk sizes). A link too slow to finish a single call within `read-write-timeout` (30 s by default) would therefore time out; that is the finest progress uplink.NET exposes.

`StartUploadAsync` / `StartDownloadAsync` return `null` when the operation already failed while it was being set up; the helper treats that as finished so the existing `upload.Failed` check still runs.

Creating the operation (`UploadObjectAsync` / `DownloadObjectAsync`) is already inside `WithTimeout(ShortTimeout)`, which is not changed here.

## Testing

New `StorjTransferTimeoutTests` (7 tests) drive `WaitForTransferAsync` with stand-in transfer tasks, since uplink.NET's operations cannot run without the native library and a satellite:

- a transfer that never moves, or stops after moving, times out after the idle timeout and is told to stop
- a transfer that moves every 300 ms for three times the 1 s timeout completes
- cancellation returns at once and tells the transfer to stop
- with no timeout, a still transfer is waited for; a failed transfer passes its error on; a `null` transfer returns

Red checks, run locally on Windows:

- with the helper reduced to `await transfer` (what master does), the three stalled/cancelled tests fail with "The transfer wait did not return within 10 seconds"
- with the helper reduced to a whole-transfer timeout (`transfer.WaitAsync(idleTimeout)`), the slow-but-moving test fails with `TimeoutException`

`StorjTransferTimeoutTests` + `StorjUploadOptionsTests`: 8/8 pass. No build warnings in the Storj project or the new test file.

Commit: [3f41670f91e5a7ba9df86b594620f8507f5abdbe](https://github.com/JamBalaya56562/duplicati/commit/3f41670f91e5a7ba9df86b594620f8507f5abdbe)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
