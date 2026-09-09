A restore on 2.3.0.1 still fails with `CryptographicException: There is not enough space on the disk` in the temporary folder ([#6606 comment](https://github.com/duplicati/duplicati/issues/6606#issuecomment-6798314029)). The restore cache added for #6606 is still the same on master in the part that causes this.

## Cause

Without `--restore-volume-cache-hint`, the restore cache has no size limit. It evicts volumes when the free space in the temporary folder is below `--restore-volume-cache-min-free` (1 GB by default). But it checks only when a decrypted volume is added to the cache (`VolumeManager`).

A volume needs room before that. While it is decrypted, the downloaded file and the decrypted file are both in the temporary folder, about twice its size, and several volumes are downloaded and decrypted at once (`--restore-volume-downloaders` and `--restore-volume-decryptors`). So the volumes in flight can use up the free space between two checks, and the decryption fails.

## The change

Before a volume is downloaded, in the mode without a size limit:

- Cached volumes are evicted until the free space covers the minimum plus twice the size of each volume in flight. The most recently used volume is kept, as its blocks are likely still requested; evicting it would only download it again.
- When that is not enough, the download waits until a volume in flight is done. One volume is always allowed, so the restore goes on.
- The size of a volume is the largest volume seen so far, or `--dblock-size` before any is seen.

The cache insert keeps its own check. With `--restore-volume-cache-hint` set, nothing changes.

## Testing

New `RestoreVolumeCacheFreeSpaceTests.RoomIsMadeBeforeAVolumeIsDownloadedAsync`. It reports a disk with 1 KB more than the minimum free space, through an internal `VolumeManager.GetAvailableFreeSpace` seam, so the cache insert never needs room but a download does.

| | master (with only the seam) | this branch |
|---|---|---|
| disk-pressure evictions | **fail**: 0 | pass: more than 0, and all files are restored |

With `RestoreHandlerTests` (including `RestoreVolumeCacheDiskPressureAsync`), `OptionsTests` and the other restore tests, 95 tests pass on Windows. No new warnings in the changed file.

`RestoreVolumeCacheDiskPressureAsync` sets the minimum free space to 999 TB, so space is never enough. A first version of this change evicted every cached volume before each download and took 51 to 108 s, close to the 120 s limit of that test. Keeping the most recently used volume brought it to about the time on master: master 29 to 39 s, this branch 41 to 47 s together with the new test.

I also restored on Linux (WSL, as root), with the temporary folder on a 48 MB tmpfs. The backup had 13 encrypted volumes of up to 6 MB, and the restore used `--no-local-db`, `--restore-volume-cache-min-free=8mb` and 4 downloaders, decryptors and file processors. Five runs of each, alternating:

| | completed | failed |
|---|---|---|
| master | 1 | 4: `CryptographicException: No space left on device` while decrypting, 19 or 20 of the 24 files restored |
| this branch | 5, all 24 files with the content of the source | 0 |

Not tried: a restore of the size in the report (hundreds of GB), and macOS.

Refs #6606

🤖 Generated with [Claude Code](https://claude.com/claude-code)
