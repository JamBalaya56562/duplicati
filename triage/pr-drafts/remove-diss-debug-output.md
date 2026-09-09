`SystemIOLinux.FileSetLastWriteTimeUtc` read the timestamp back after setting it and wrote `DISS: <path> <diff>` to stderr whenever the two differed. The block was added as a debugging aid in [817b1d5bc2c35ee1e306881a1bae361e8be7a904](https://github.com/duplicati/duplicati/commit/817b1d5bc2c35ee1e306881a1bae361e8be7a904) ("Try to debug time discrepency") and came in with the .NET 8 port (#5111). It only prints; the read-back value is not used otherwise.

The line shows up on restore whenever the target filesystem stores timestamps with less precision than the backup recorded, e.g. a restore to an ext2 volume with 128-byte inodes (1-second timestamps) printed one `DISS:` line per file. This removes the read-back and the output; setting the timestamp is unchanged.

Checked on Linux (WSL) with a small console program calling `SystemIO.IO_OS.FileSetLastWriteTimeUtc` with sub-second ticks: before, ext2 (1 s precision) printed `DISS: /mnt/ext2s/f.txt -1234567`; after, nothing on stderr. ext4 printed nothing in either case.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
