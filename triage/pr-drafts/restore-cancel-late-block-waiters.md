## What happens

A restore that meets a volume it cannot produce can stop and never finish. It does not fail and does not time out; it waits forever. This happens whichever stage the volume fails in: download (the file does not match its recorded hash), decryption, or decompression.

Reproduced on Windows by repeating a `restore-test` of a backup in which one dblock is damaged. On current master the run stops within a few repeats; each repeat takes a few seconds.

### Why

When a stage fails, the pipeline is retired from that stage outwards. Five places then leave a process waiting for something that will never come. Each was found from a dump of a stopped run (`dotnet-dump`, `dumpasync`) and from the order of events in the log.

1. **A block waiter registered after `CancelAll` is never answered.** The block manager's volume consumer calls `CancelAll` when its input retires, and that fails only the waiters registered at that moment. `GetAsync` can register a waiter afterwards, and nothing will ever set that block.

The other four have one shape: **a stage stops, and the stage that writes to it keeps waiting to hand over its next item.**

| Stage that stops | Writer left waiting | Channel |
|---|---|---|
| `VolumeManager` | `GetAsync` / `CheckCountsAsync` (block requests and evictions) | `VolumeRequest` |
| `VolumeManager` | `VolumeDecryptor` (decrypted volumes) | `VolumeResponse` |
| a block handler, on a `RetiredException` | its `FileProcessor` (next request, or waiting for the response) | the handler's request and response channels |
| `VolumeDownloader`, on a download error | `VolumeManager` (next volume to download) | `DownloadRequest` |
| `VolumeDecryptor`, on a decryption error | `VolumeDownloader` (next downloaded volume) | `DecryptRequest` |

`VolumeManager` and the block handler did not retire these channels at all on that path. The downloader and the decryptor did retire their input, but with `Retire()`, and that is not enough: CoCoL's `Retire()` waits for a buffered channel to be read empty first, so with no reader left it never completes and every writer stays blocked, both the ones already waiting and any later one. Measured with CoCoL 1.8.4, a channel with a full buffer and a write waiting, retired from the read end:

| Retired with | Buffer of 2 | Buffer of 1 |
|---|---|---|
| `Retire()` | writer still blocked | writer still blocked |
| `Retire()` from a `RunTask` process | writer still blocked | writer released |
| `RetireAsync(immediate: true)` | writer released with `RetiredException` | writer released with `RetiredException` |

The default `restore-channel-buffer-size` is the processor count, so the "buffer of 2" column is the one that applies in practice. With a buffer of one, the downloader case does not stop, which is why it needs a larger buffer to reproduce.

## The change

- `CancelAll` records that the volumes have stopped arriving, and `GetAsync` fails a waiter it registers after that point. Waiters are removed before they are failed, so the call is safe to repeat and to run alongside `GetAsync`.
- `VolumeManager` retires `VolumeRequest` and `VolumeResponse` immediately in its `finally`.
- A block handler retires its request and response channels immediately on both exit paths.
- `VolumeDownloader` (on an error or a cancellation) and `VolumeDecryptor` (on an error) retire their input immediately instead of with `Retire()`.

The output channels are left as they were: they are retired by their writer, and a writer's `Retire()` correctly lets the readers finish what is buffered.

In every case the waiting process now receives a `RetiredException`, the same path the restore already takes for a waiter that was registered in time, so the damaged files are reported as failed as before.

## Red to green

Windows, a backup of 12 files, with the dblock holding data for the fewest files damaged, then `restore-test` repeated. The rows for each failure mode add to the build above them.

**Download fails** (the dblock is damaged, so its hash no longer matches), `dblock-size` 100 KB, 40 repeats:

| Build | Result |
|---|---|
| master | stopped on repeat 3 |
| 1: late waiters are failed | stopped on repeat 20 (a second run: 28) |
| + `VolumeManager` and the block handler retire their channels with `Retire()` | stopped on repeat 17 (a second run: 6) |
| + `VolumeRequest` retired immediately | stopped on repeat 9 |
| + the handler's channels retired immediately | 40 of 40 finished, 14 of them with a damaged volume holding a single file (the case that stopped most often) |

**Download fails, many volumes, small buffer** (`dblock-size` 25 KB for 20 volumes, `restore-channel-buffer-size` 2, one downloader), 20 repeats:

| Build | Result |
|---|---|
| all of the above | stopped on repeat 7, `VolumeManager` waiting in `DownloadRequest.WriteAsync` |
| + the downloader retires its input immediately | 20 of 20 finished |

**Decryption fails** (as above, two downloaders, with the damaged file's hash recorded in the database so the download passes), 20 repeats:

| Build | Result |
|---|---|
| all of the above | stopped on repeat 4, a downloader waiting in `DecryptRequest.WriteAsync` |
| + the decryptor retires its input immediately | 20 of 20 finished, every one of them failing in the decryptor |

**Decompression fails** (the zip inside the volume is damaged and the volume encrypted again, the hash recorded as above), 20 repeats:

| Build | Result |
|---|---|
| all of the above | stopped on repeat 5, the decryptors waiting in `VolumeResponse.WriteAsync` |
| + `VolumeManager` retires `VolumeResponse` immediately | 20 of 20 finished, 19 of them failing in the decompressor |

`RestoreTestHandlerTests`, `RestoreHandlerTests` and `RepairWithMissingRemoteFiles` are green.

There is no new test: whether a run stops depends on the order in which the processes retire, so a test would only catch it some of the time. The repeated runs above are the reproduction.

### Not changed

`VolumeDecompressor` and the block manager's volume consumer also retire their input with `Retire()` when they fail. Neither stopped in the runs above, so they are left as they are.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
