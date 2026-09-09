Title: Let sync keep the modification times of the local files

A sync gives every uploaded file the time of the upload, because the backends have no way to receive a modification time. On Nextcloud, ownCloud and MagentaCloud over WebDAV, the files therefore show the sync time instead of their own time (#7702).

## The change

- New option `--sync-keep-modification-time` (off by default). With it, sync passes the modification time of the local file to the destination.
- New interface `IModificationTimeEnabledBackend` with `PutAsync(name, stream, lastModifiedUtc, ct)`:
  - WebDAV sends the time in the `X-OC-Mtime` header (Unix seconds), which Nextcloud and ownCloud apply. rclone sends the same header.
  - The local folder backend sets the time on the written file.
  - Other backends are unchanged and keep the upload time.
- `IBackendManager` gets an overload of `PutFileUnencryptedWithPathAsync` with the time. It has a default implementation, so the existing test fakes still compile.
- WebDAV keeps the time in whole seconds. With the option on, sync compares the times at that precision. Otherwise every file would look newer than its copy and be uploaded again on every run.

## Testing

- New `SyncKeepModificationTimeTests`, 5 tests: the WebDAV header (2), the time on `file://` (2), and no second upload with a backend that keeps whole seconds (1). Without passing the time, 2 of them fail; without the rounding, 1 fails.
- With `SyncHandlerTests`, `CaseInsensitiveDestinationSyncTests` and the WebDAV tests: 94 pass, 2 skipped on Windows (case-sensitive file system tests).
- Against Nextcloud 31.0.14 (the official `nextcloud:31-apache` image, local), syncing two files with times from 2020 and 2021:
  - Without the option, Nextcloud shows the upload time.
  - With the option, it shows the original times.
  - A second sync with the option uploads nothing, and the ETags stay the same.
- Local folder destination: the original times with the option, the upload time without it.

Not tried: ownCloud and MagentaCloud themselves. The documentation repository does not describe the new option yet.

Fixes #7702

🤖 Generated with [Claude Code](https://claude.com/claude-code)
