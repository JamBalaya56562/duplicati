Title: Upload one volume at a time to a local folder by default

A local folder is often an external hard disk. Writing four volumes to it at once, the default number of concurrent uploads, made the backup slow there, and the option to limit it was hard to find (#4808).

## The change

- When neither `--asynchronous-upload-limit` nor its alias `--asynchronous-concurrent-upload-limit` is set, and the destination is a local folder (`file://` or a plain path), one volume is uploaded at a time.
- A limit that is set is used as before, and the other destinations keep the default of four.
- The new `Options.GetAsynchronousConcurrentUploadLimit(backendUrl)` is called by `BackendManager.Handler` with the real destination URL. The help mentions the local folder default.

## Testing

- New `LocalDestinationUploadLimitTests`, 10 tests: `file://` and plain paths get 1, other schemes 4, and a set limit (also through the alias) wins. On master every destination gets 4.
- With `UploadLimitZeroTests` and `DeprecatedUploadOptionTests`, all pass. The interruption, failure and upload tests (110 tests in 14 classes) pass too; the `file://` destinations in them now upload one volume at a time.

Fixes #4808

🤖 Generated with [Claude Code](https://claude.com/claude-code)
