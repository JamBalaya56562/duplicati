Fixes #6629

## What happens

The errors in the issue since 2.2.0.3 read "The operation was cancelled because it exceeded the configured timeout of 0:01:40. Network timeout can be adjusted in ClientOptions.Retry.NetworkTimeout." This timeout is the Azure client's `Retry.NetworkTimeout`, which is 100 seconds by default and applies to each request as a whole. #6632 ([`b5397e72e1c0efc6d041dbe60f18bfef9c25e30d`](https://github.com/duplicati/duplicati/commit/b5397e72e1c0efc6d041dbe60f18bfef9c25e30d)) removed the `HttpClient` timeout and set the retries, but did not change this one.

`BlockBlobClient.UploadAsync` sends a file of up to 256 MiB in a single request by default, so a volume that takes more than 100 seconds to send always fails, and the retries send the whole volume again. With 100 MB volumes, four uploads at a time and a 2 MB/s connection, as in one of the comments, each upload gets about 0.5 MB/s and needs about 200 seconds.

## The change

Uploads are sent in blocks of 4 MiB, one block at a time (`StorageTransferOptions` with `InitialTransferSize`, `MaximumTransferSize` and `MaximumConcurrency = 1`), and then committed with a block list. Each request then takes 100 seconds only below about 40 KB/s for one upload, and a retry sends one block again rather than the whole volume. A file of up to 4 MiB is still sent in one request.

The network timeout itself is not changed. It is also what stops a stalled transfer: the download passes the target stream itself to `DownloadToAsync`, not the wrapper that observes the read-write timeout, and that wrapper only notices a stall when the next read or write is called.

To test the requests, `AzureBlobWrapper` gets an `internal` constructor that takes the `HttpMessageHandler`.

## Checked

`AzureBlobUploadBlockTests` (new) records the requests an upload sends through a stub handler:

| Test | Before | After |
|---|---|---|
| A file of 8 MiB + 1 KiB | one request of 8,389,632 bytes | blocks of at most 4 MiB, adding up to the file, and one block list |
| A file of 1 KiB | one request | one request |

I also uploaded 8 MiB through `AzureBlobWrapper.AddFileStream` and the real Azure pipeline, with the default network timeout, to a stub handler that takes the body at 64 KiB/s as it is read from the source (a probe, not part of this PR):

| | Result |
|---|---|
| Before | failed after 1:40 with "The operation was cancelled because it exceeded the configured timeout of 0:01:40. Network timeout can be adjusted in ClientOptions.Retry.NetworkTimeout.", as in the issue |
| After | two blocks of 4 MiB, 64 seconds each, then the block list; succeeded after 2:09 |

The blocks are read from the source as they are sent, so the read-write timeout of the source stream (30 seconds by default) keeps being reset. The stream the upload gets is a `FileStream` wrapped in streams that pass `CanSeek` through, so the client does not need to buffer a block first.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
