The wasted-space report (the query that creates the "UsageReport" table) was rewritten in #7340 (76f63480518b6340dcbd5982bd5e74b69a743265). It no longer joins every fileset through to every block. The first stable release with it is 2.4.1.0.

I timed it with the official Docker images. The data was 20,000 files of 20 KB with 1 KB blocks (about 20 blocks per file, as in the synthetic test in #7340) and 40 versions, a 196 MB database. On it I ran `compact` twice:

| | 2.3.0.0 | 2.4.1.0 |
|---|---|---|
| first compact (also merges the small volumes) | 145.2 s | 71.6 s |
| second compact (nothing left to merge, so mostly the report) | 21.9 s | 5.6 s |

These are the times of the whole compact operation; I did not time the report query on its own.

If someone still sees the report take hours on 2.4.1.0 or later, the database size and the number of versions would help. Otherwise I think this can be closed.
