Recreating the database is slow on large backups (#2889). This fixes one of the queries behind it.

`LocalRecreateDatabase.FindMissingBlocklistHashesAsync` skipped the blockset entries that were already there with:

```sql
BlocksetID || ':' || Index NOT IN (SELECT BlocksetID || ':' || Index FROM BlocksetEntry)
```

So the whole `BlocksetEntry` table was turned into strings each time it ran. It runs once after the index files, and once for each block volume that is read (`RecreateDatabaseHandler`).

## The change

`NOT EXISTS` on the two columns, which uses the primary key `(BlocksetID, Index)`. Both columns are integers and never null, so the same rows are inserted.

## Testing

Measured with a scratch program on the filter alone, with the production pragmas of `SQLiteLoader.LoadConnectionAsync`, in an open transaction, after `ANALYZE`. Each number is the median of 5 runs, alternating between the two queries, with half of the candidates already in the table:

| rows in `BlocksetEntry` | candidates | before | after |
|---|---|---|---|
| 1M | 100k | 1379 ms | 386 ms |
| 1M | 1M | 4756 ms | 3492 ms |
| 4M | 400k | 6960 ms | 1191 ms |
| 4M | 4M | 19591 ms | 14202 ms |

Both queries insert the same rows in every case. Not measured: the time of a whole recreate.

The recreate and repair tests reach this query and check its result: with the query broken to `WHERE 0 AND NOT EXISTS`, 25 of them fail. When the branch was written, the 70 tests of 14 recreate and repair classes passed.

Rebased on master [d6dcdd0c7](https://github.com/duplicati/duplicati/commit/d6dcdd0c734f99d9c5101e55cd3dc287b191e5e9), on Windows: the `*Recreate*` tests, 54 passed. No warnings in the changed file.

Refs #2889

🤖 Generated with [Claude Code](https://claude.com/claude-code)
