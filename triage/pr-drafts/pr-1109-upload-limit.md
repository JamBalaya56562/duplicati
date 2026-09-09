The help of `--asynchronous-upload-limit` says that zero disables the limit, but `BackendManager.Handler` clamped the value with `Math.Max(1, ...)`. Zero allowed one upload at a time, so every upload waited for the one before it.

Zero now means no limit (`int.MaxValue`). Other values are kept as before, and a negative value is still 1.

## Testing

New `UploadLimitZeroTests` runs a backup of 40 files with 100 KB block volumes against a backend that holds every upload, and counts the uploads held at the same time:

| test | master | this branch |
|---|---|---|
| `ZeroLetsMoreThanTheDefaultUploadAtOnceAsync` (limit 0) | **fail**: 1 at a time | pass: 20 at a time |
| `AGivenLimitIsStillKeptAsync` (limit 2) | pass: 2 | pass: 2 |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `UploadLimitZeroTests`, 2 passed. No warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
