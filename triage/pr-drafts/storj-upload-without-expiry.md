Fixes #6706

## What happens

The backend uploads with `new UploadOptions()`, which has no expiry time. uplink.NET's `UploadOptions.ToSWIG` sends a missing expiry time as `DateTimeOffset.MaxValue`, so the native library gets 253402300799 (9999-12-31), and uplink-c sets an expiry time for any value above zero. The satellite refuses an upload with an expiry time into a bucket with default retention settings: "cannot specify an object expiration time when uploading into a bucket with default retention settings". So no upload to a bucket with Object Lock and default retention can work, as the issue says.

The "object not found" in the issue comes from the connection test, which downloads the file it just tried to upload without checking whether the upload failed. That is left as it is here; with the expiry time fixed, the upload goes through.

## The change

Both uploads use `CreateUploadOptions()`, which sets the expiry time to `DateTime.UnixEpoch`. That is sent as 0, which uplink-c treats as no expiry.

## Checked

`StorjUploadOptionsTests.AnUploadHasNoExpiryTime` (new) checks that the options the backend uses have `Expires` set to `DateTime.UnixEpoch`, and on Windows also converts them the way uplink.NET does before an upload and reads the expiry time handed to the native library. With the old `new UploadOptions()` the test fails (`0001-01-01` instead of 1970), and the value handed to the native library is 253402300799; with the change it is 0. The test does not load the native library on Linux and macOS: it contains a Go runtime, and on the Linux CI loading it made the test process crash later, in other tests.

I have no Storj bucket with Object Lock to try an upload against. The refusal is from reading the satellite code ([`validateObjectRetentionWithTTL`](https://github.com/storj/storj/blob/main/satellite/metainfo/endpoint_object.go)) and uplink-c's [`upload.go`](https://github.com/storj/uplink-c/blob/main/upload.go) (`if options.expires > 0`).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

