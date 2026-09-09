The synchronization tool, which also runs after a backup, refused any backend that cannot stream:

```
Backend does not support streaming operations.
```

- The file backend cannot stream with `--use-move-for-put`, the option suggested in #6546.
- The backup passes its own options to the source of the synchronization (`RemoteSynchronizationHandler`, `SrcOptions: options.RawOptions`).
- So a backup to a local folder with that option could not be synchronized.
- Backends that only implement `IBackend`, such as Rclone and Tencent COS, could not be used for synchronization at all.

## The change

In `LightWeightBackendManager`, a backend that cannot stream is used through a temporary file with the file-based `PutAsync` and `GetAsync` of `IBackend`. Listing, deleting and the rename fallback also go through `IBackend`. Backends that can stream are used as before.

## Testing

New `LightWeightNonStreamingBackendTests`:

| test | master | this branch |
|---|---|---|
| file backend with `--use-move-for-put`, copy and rename fallback (2 cases) | **fail**: "does not support streaming operations" | pass |
| a fake backend that only implements `IBackend` | **fail**: same error | pass |
| `RemoteSynchronizationRunner` with `use-move-for-put=true` on the source | **fail**: same error | pass |

The master column was measured on master when the branch was written. Not tried with a real Rclone remote.

Rebased on master [d6dcdd0c7](https://github.com/duplicati/duplicati/commit/d6dcdd0c734f99d9c5101e55cd3dc287b191e5e9), on Windows: `LightWeight*` tests, 6 passed, and `RemoteSynchronization*` tests, 75 passed. No warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
