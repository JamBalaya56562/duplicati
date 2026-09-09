A restore starts half as many volume downloaders as there are processors. A restore from a local folder, which is often an external hard disk (#6829), then reads several volumes from it at once, and is slow there.

## The change

- When `--restore-volume-downloaders` is not given and the destination is a local folder (`file` scheme), the restore uses one volume downloader.
- A given number is used as before, and other destinations keep the default (`ProcessorCount / 2`).
- New `Options.GetRestoreVolumeDownloaders(backendUrl)`. `RestoreHandler` keeps the `backendUrl` of `RunAsync` and uses it in the new restore flow.

Not changed: the legacy restore, `RestoreTestHandler` (which gets no URL), and the number of decompressors, decryptors and file processors, which do not read from the destination.

## Testing

New `LocalRestoreDownloaderTests`, 10 tests: 8 for the option, and 2 that back up to and restore from a real `file://` folder and count the started downloaders from the `Volume downloader retired` messages.

| | master | this branch |
|---|---|---|
| default, local folder (8 cores) | 4 downloaders | 1 |
| `--restore-volume-downloaders=3` | 3 | 3 |

All 10 pass, and `RestoreHandlerTests` (34 tests) pass. No new warnings in the changed files.

Fixes #6829

🤖 Generated with [Claude Code](https://claude.com/claude-code)
