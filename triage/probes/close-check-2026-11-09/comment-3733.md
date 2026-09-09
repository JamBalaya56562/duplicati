I think the restore rewrite fixed this. Since 2.1.0.3 (76240550ed34607ad571d8651552f82553e50b65, #5728), a file is restored front to back: its blocks are requested in file order and appended (`Operation/Restore/FileProcessor.cs`), instead of each dblock volume patching the files it has blocks for.

I checked it with the official Docker images: one 300 MB random file, 100 KB blocks, 5 MB dblocks (61 volumes), the source deleted before the restore, and the size and the allocated space of the restored file sampled while it was written:

- 2.0.6.1: the writes jumped around (the write position went 93.8 MB → 275.2 MB → 59.6 MB), and the file had holes of up to 14.1 MB during the restore.
- 2.2.0.3 and 2.4.1.0: the size grew in more than 340 steps, and the file never had a hole.

All three restored the file correctly. This was on Linux (ext4 in Docker); I did not measure NTFS fragmentation or the total amount written. `--restore-legacy=true` still selects the old process.

Since 2.4.0.0, `--restore-preallocate-size=true` also sets the file to its final size before the blocks are written. Before that release the option was read under another name and had no effect (#7064).

If nobody still sees this on 2.1.0.3 or later, I think this can be closed.
