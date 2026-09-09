Title: Resume a Google upload of a stream that cannot seek

The resumable upload of Google Drive and Google Cloud Storage (`GoogleCommon.ChunkedUploadAsync`) seeks back with `stream.Position = offset`. It does this when a 308 says that only part of a chunk was received, and when it asks for the received position after a failed request. A stream that cannot seek throws `NotSupportedException` there. The Google Drive backend tests hit this on macOS in CI, with the tester's non-seekable stream.

## The change

- A stream that cannot seek is read one chunk (10 MiB) at a time into a buffer, which keeps the data from the confirmed offset to the stream's position. When the resume point is inside the buffer, the upload continues from there, and the rest of the chunk comes from the stream.
- A resume point outside the buffer throws `InvalidOperationException`. A stream that ends before its `Length` throws `InvalidDataException`. Neither is retried.
- Seekable streams work as before.

## Testing

`GoogleDriveResumeUploadTests`, extended. The stub now records the uploaded body and can answer with a 308 for part of the first chunk.
- With a non-seekable stream: resuming at byte 400 after a 503, and uploading 12 MiB where only 5 MiB of the first chunk is received. Both failed with `NotSupportedException` before the change. Now they pass, and the received body is the same as the source.
- The same 308 with a seekable stream passes before and after.
- All 127 Google tests pass.

Not tried: the real Google services.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
