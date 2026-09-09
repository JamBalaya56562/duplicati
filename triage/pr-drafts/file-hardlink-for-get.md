Title: Link downloaded files from a local folder destination instead of copying them

The local folder destination copies every volume it reads to the temporary folder. With large volumes this is slow when both are on the same disk (#6546).

## The change

- New option `--use-hardlink-for-get` for the file backend (off by default). `GetAsync(name, filename)` creates a hard link (`CreateHardLinkW` on Windows, `link` elsewhere) and falls back to copying when the link cannot be made, for example on another volume.
- Like `--use-move-for-put`, it turns off streaming transfers, as the streaming download writes a new file.
- Found while doing this: parity repair wrote the repaired data back over the downloaded file (`Par2Parity`). With a link, that would also change the stored volume. `GetOperation.TryRepairWithParityAsync` now repairs a copy and returns it.

## Testing

- New `FileBackendHardlinkGetTests`, 6 tests, on Windows and Linux:
  - A link is made, and streaming is turned off.
  - A compact and a restore (with and without encryption) work.
  - A repair with a fake par2 does not change the stored volume.
- Without the change, 5 of them fail. With only `GetOperation` reverted, the parity test fails.
- On Linux with `/tmp` on tmpfs the link fails and the copy is used, so the tests put the file next to the destination.
- The existing parity and file backend tests pass (5 skipped without par2).

Not measured: the time of a large compact with links.

Fixes #6546

🤖 Generated with [Claude Code](https://claude.com/claude-code)
