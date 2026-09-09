`S3MinioClient.AddFileStreamAsync` caught `MinioException`, logged it and returned, so an upload that the server refused looked stored. The upload was neither retried nor reported, and the file was only found missing by the next verification. Every other `catch` in the client throws again; this one has not since the first version of the client.

The change adds `throw;` there, so a refused upload fails as it does with the AWS client.

## Related issues

- #6489 (closed) reported that the Minio client treated a 4xx answer to a PUT as success, and was closed by pinning the Minio library to 6.0.0, on the view that the library did not throw. The new test shows that the pinned 6.0.0 library does throw for a refused upload; it was the catch in Duplicati that hid it.
- #4209 reports that all files of a first backup were missing afterwards. That fits an upload failure that was not reported, but I could not confirm the cause, so this PR only refers to it.

## Testing

New `S3UploadErrorTests.ARefusedUploadFails`, with a local `HttpListener` that answers every object upload with 403 `AccessDenied`, for both clients:

| test | master | this branch |
|---|---|---|
| `ARefusedUploadFails("aws")` | pass | pass |
| `ARefusedUploadFails("minio")` | **fail**: no exception | pass |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `S3UploadErrorTests`, 2 passed. Before the rebase, the offline S3 tests, 35 passed. No warnings in the changed files.

Refs #6489
Refs #4209

🤖 Generated with [Claude Code](https://claude.com/claude-code)
