`--zip-compression-method` offers GZip, Xz and Deflate64, but these cannot be written to a ZIP archive by SharpCompress, so a backup with one of them fails with "Invalid compression method". They are removed from the list. No archive can have been made with them.

## Tests

`EveryZipCompressionMethodCanBeWrittenAndRead` writes and reads an archive with each method that is offered, and fails on master for these.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
