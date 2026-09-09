A backup with another `--file-hash-algorithm` or `--block-hash-algorithm` than the default could not be restored with the recovery tool, for three reasons:

- The files were verified with the block hash algorithm, as the option was read twice.
- The block of a file with a single block was looked up by the hash of the file.
- With SHA512 for the blocks, the lines of the index were longer than the 128 bytes the tool could read.

## Tests

`RecoveryToolHashAlgorithmTests` restores files of several sizes with four combinations of the algorithms. Three of them fail on master.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
