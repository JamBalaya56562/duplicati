# S3 (MinIO client): apply the list timeout to the listing

Branch: `fix/s3-minio-list-timeout` (commit [65a8cde1712f4803092b88508c40845095bfb65e](https://github.com/JamBalaya56562/duplicati/commit/65a8cde1712f4803092b88508c40845095bfb65e)), based on master 7cdde158.

## Problem

`S3MinioClient.ListBucketAsync` wrapped `m_client.ListObjectsAsync(...)` in `Utility.WithTimeout(ListTimeout, ...)`. In Minio 6.0.0, `ListObjectsAsync` returns an `IObservable<Item>` at once. The list requests are only sent later, while `ToAsyncEnumerable` reads the observable, and that loop used only the caller's token. So `list-timeout` covered only creating the observable, not the listing.

The token passed to `ListObjectsAsync` also came from the `CancellationTokenSource` inside `WithTimeout`, which is disposed as soon as `WithTimeout` returns. So it could not stop the requests either. (I read this from the code; the test below shows the effect.)

A server that stops answering a list request made the listing wait until the HTTP client gave up.

The listing used to have a timeout. With Minio 6.0.4 the listing went through `Utility.WithPerItemTimeout(m_client.ListObjectsEnumAsync(...), ListTimeout, ...)` (added in 8aee23c27). When Minio was reverted to 6.0.0 for #6489 in [0497de7e9f9fc9307acf9064e0e70a070391e1c7](https://github.com/duplicati/duplicati/commit/0497de7e9f9fc9307acf9064e0e70a070391e1c7), the listing was rewritten around the observable and the per-item timeout was lost. This change puts it back.

## Change

- `ToAsyncEnumerable` takes a timeout and applies it to each wait for the server, that is, each `WaitToReadAsync` on the channel. When the timeout passes it throws `TimeoutException`; a cancellation by the caller stays an `OperationCanceledException`. The time the caller spends on the items it receives does not count. This is close to the AWS client, which applies `list-timeout` to each `ListObjectsV2` page request.
- `ListObjectsAsync` now gets a token from a source linked to the caller's token. That source lives as long as the listing and is cancelled when the listing ends, so requests still running after a timeout or an early stop are cancelled.
- I did not use the existing `Utility.WithPerItemTimeout`. It resets its timer in a `finally` block that only runs when the caller asks for the next item, so the caller's own processing time counts toward the timeout. When that happens it throws an `OperationCanceledException`, not a `TimeoutException`.

## Testing

New unit tests in `S3MinioListTimeoutTests`. The server is a local `TcpListener` that answers the bucket check (`HEAD`) with 200, `list-timeout` is 1 s, and the region is set so no location lookup is made.

- `ListStopsAtTheListTimeout`: the server never answers the list request.
  - master: the listing had not returned after 15 s (the test fails)
  - this branch: `TimeoutException` after about 1 s
- `ListReturnsTheFiles`: the server answers with a one-object `ListBucketResult`, and the listing returns `file`. This checks that normal listings still work. It passes on this branch.

No other open branch touches `S3MinioClient.cs`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
