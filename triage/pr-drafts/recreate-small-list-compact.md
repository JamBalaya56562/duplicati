Part of #7538

## Summary
A recreate lists the single block of every small file and every metadata entry in a temporary table (`TempSmalllist`). The temporary tables are kept in memory (`temp_store=MEMORY`). The table had a rowid and two unique indexes, on `("FileHash", "BlockSize")` and `("BlockHash", "BlockSize")`. For 100,000 small files it grew the temporary store to 42 MB.

A restore without a local database runs this recreate first, on the same connection. The memory of a temporary store is only returned when the connection closes, so this table sets the floor for the restore's memory.

The table is now `WITHOUT ROWID`, with `("FileHash", "BlockSize")` as its primary key and no other index:
- The content decides both hashes, so a file hash and a size map to a single block hash. The second index added no uniqueness.
- The queries only scan the table and look up `Block` and `Blockset`. They never look up the table itself.
- `"BlockHash"` is stored as `NULL` when it equals `"FileHash"` (`NULLIF(@BlockHash, @FileHash)`). The two are equal whenever the block and the file use the same hash algorithm, which is the default. Every query reads it as `COALESCE("BlockHash", "FileHash")`.

With 200,000 rows of base64 SHA-256 hashes in Python's SQLite (3.53.1), the table took 45.6 MB before and 11.8 MB after.

This is on top of the change that computes the restore target paths.

## Measured
Restore of 100,000 small files without a local database, with `--restore-cache-max=0b`. Release build on Windows, two runs each, alternating between the base and this change. Peak private bytes:

| | base | this change |
|---|---|---|
| Without a local database | 332 MB, 327 MB | 303 MB, 296 MB |

The run times were 686–806 s for the base and 680–767 s for this change.

## Testing
- New test `RecreateSmallListTests.TheSmallFileListHasNoExtraIndexAndSkipsAnEqualBlockHashAsync`. It adds links to a recreate database and reads the table and its indexes. On the base it fails with `The small file list has indexes besides its key` (`Index_Block_…`, `Index_File_…`). With the change it passes.
- These tests passed, 155 in total: those matching `Duplicati.UnitTest.Recreate`, `Duplicati.UnitTest.Repair`, `ExperimentalRecreateTests`, `EmptyFileTests`, `ZeroLengthMetadataTests`, `RestoreFromPartiallyRecreatedDatabaseTests` and `RestoreHandlerTests`, and `BorderTests` with MD5, SHA384 and mixed block/file hash algorithms. No new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
