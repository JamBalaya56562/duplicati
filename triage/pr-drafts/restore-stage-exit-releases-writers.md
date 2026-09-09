## What happens

A restore can still stop and never finish when a stage of its pipeline fails. #7357 released every process that was waiting when a volume failed to download, decrypt or decompress, but four paths were left:

- **One decompressor.** The default is half the processor count, at least one, so this is the normal setup on a machine with two or three cores.
- **A stage stopped by the stage after it**, rather than by its own error. For instance, a decryptor whose output is retired because the volume manager has stopped.
- **The block manager's volume consumer failing.**
- **A file processor failing** while its block handler is still answering the requests it sent ahead.

Reproduced on Windows by repeating a `restore-test` of a backup of 12 files (`dblock-size` 25 KB, 20 volumes, `restore-channel-buffer-size` 2) in which the zip inside one volume is damaged. The volume is encrypted again and its new hash recorded in the database, so the download and the decryption pass and the decompression fails.

### Why

It is the same shape as in #7357: a stage stops, and the stage that writes to it keeps waiting to hand over its next item, because the stopping stage does not retire its input immediately. CoCoL's `Retire()` waits for a buffered channel to be read empty first, so with no reader left it never completes.

1. **`VolumeDecompressor` on a decompression error** retired its input with `Retire()`. With more than one decompressor, the others read the buffer empty and the retirement completes. With a single one, nothing reads it, and the volume manager waits in `DecompressionRequest.WriteAsync` forever. Found from a dump of the stopped run.

2. **`VolumeDownloader`, `VolumeDecryptor` and `VolumeDecompressor` stopped by a `RetiredException`** did not retire their input at all. #7357 made them retire it on their own errors only. When the retirement comes from downstream, the stage before can still be waiting to hand over. With the fix for 1 in place, the run stopped with a downloader waiting in `DecryptRequest.WriteAsync` after all four decryptors had left through their `RetiredException` path. Found from a dump of the stopped run.

3. **The block manager's volume consumer on an error** retired its input with `Retire()`. It is the only reader of `DecompressedBlock`, so the decompressors wait in `DecompressedBlock.WriteAsync` forever. Found from a dump of the stopped run.

4. **`FileProcessor` when it stops** retired its response channel with `Retire()`. A file processor sends up to `restore-channel-buffer-size` block requests ahead of the one it reads, and its block handler keeps answering them after the processor has gone. With nothing reading the responses, the handler waits in the response channel's `WriteAsync` forever, and the block manager with it. Found from a dump of the stopped run.

## The change

- `VolumeDecompressor` retires its input immediately on an error, as `VolumeDownloader` and `VolumeDecryptor` already do since #7357.
- `VolumeDownloader`, `VolumeDecryptor` and `VolumeDecompressor` also retire their input immediately when they stop on a `RetiredException`.
- The volume consumer retires its input immediately when it fails.
- `FileProcessor` retires its response channel immediately on every exit path. Its request channel is left as it was: the processor is its writer, and a writer's `Retire()` correctly lets the handler finish what is buffered.

On a normal end, a stage only gets a `RetiredException` once its input has been retired and read empty, so the added retirement does nothing there.

## Red to green

**Decompression fails** (1 and 2). Windows, the setup above, 20 repeats per run:

| Build | Decompressors, downloaders, decryptors | Result |
|---|---|---|
| master ([`89435a56`](https://github.com/duplicati/duplicati/commit/89435a56880357227b14d47fa054ccc920c30408)) | 1, 2, 4 | stopped on repeat 1, the volume manager waiting in `DecompressionRequest.WriteAsync` |
| + 1 | 1, 2, 4 | stopped on repeat 19, a downloader waiting in `DecryptRequest.WriteAsync` |
| + 1 and 2 | 1, 2, 4 | 20 of 20 finished |
| + 1 and 2 | 1, 1, 4 | 20 of 20 finished |
| + 1 and 2 | 2, 2, 1 | 20 of 20 finished |
| + 1 and 2 | 1, 1, 1 | 20 of 20 finished |

In the finished runs, 72 of the 80 repeats failed in the decompressor, 2 in the decryptor, and the other 6 finished before they reached the damaged block.

**The volume consumer fails** (3). I found no way to make `cache.Set` fail from the outside, so for this run the consumer was made to throw on its Nth block (a temporary change, not part of this PR), on an undamaged backup of the same shape. 20 repeats per run:

| Build | Decompressors, downloaders, decryptors | Fails on block | Result |
|---|---|---|---|
| 1 and 2 | 2, 2, 2 | 6th | stopped on repeat 8, the decompressors waiting in `DecompressedBlock.WriteAsync` |
| + 3 | 2, 2, 2 | 6th | 20 of 20 finished |
| + 3 | 1, 1, 1 | 6th | 20 of 20 finished |
| + 3 | 4, 2, 4 | 6th | 20 of 20 finished |
| + 3 | 2, 2, 2 | 1st | 20 of 20 finished |
| + 3 | 2, 2, 2 | 31st | 20 of 20 finished |

Every finished repeat reported the restore as an error, as it should.

**A file processor fails** (4). As for 3, a file processor was made to throw on its Nth block write (a temporary change, not part of this PR), on an undamaged backup of the same shape. 20 repeats per run:

| Build | File processors | `restore-channel-buffer-size` | Result |
|---|---|---|---|
| 1 to 3 | 4 | 4 | stopped on repeat 3, a block handler waiting in the response channel's `WriteAsync` |
| 1 to 3 | 2 | 2 | 20 of 20 finished |
| 1 to 3 | 1 | 2 | 20 of 20 finished |
| 1 to 3 | 2 | 0 | 20 of 20 finished |
| 1 to 3 | 1 | 0 | 20 of 20 finished |
| + 4 | 4 | 4 | 20 of 20 finished |
| + 4 | 4 | 8 | 20 of 20 finished |
| + 4 | 2, 1, 2, 1 | 2, 2, 0, 0 | 20 of 20 finished each |

Every finished repeat reported the restore as an error with the right number of failed files: one with several file processors, all twelve with one.

`RestoreTestHandlerTests`, `RestoreHandlerTests` and `RepairWithMissingRemoteFiles` were green with 1 and 2. The version with 3 and 4, rebased on current master, has not been run locally; CI checks it.

As in #7357 there is no new test: whether a run stops depends on the order in which the processes retire. The repeated runs above are the reproduction.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
