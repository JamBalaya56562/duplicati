I think this was fixed in 2.0.3.7 (canary) by 30814472719c9e19c4552466f3b7a93664cef82a ("Added an on-the-fly index builder to avoid querying the database for each volume"), the change mentioned above.

The query in the report built each index file from the database, once for each uploaded volume. Since that change, the backup adds each block to an in-memory index volume as it writes the block (`DataBlockProcessor.cs`: `indexvolume.AddBlock`, then `indexvolume.CreateVolumeAsync`), so it no longer runs that query for every volume. I checked the file in each release tag: 2.0.3.6 builds the index from the database, and 2.0.3.7 and later use the on-the-fly builder. On current master, a backup of 18 MB with `--dblock-size=2mb` uploaded 19 volumes and 19 index files.

The database query still exists in a newer form (`GetBlocklistsAsync`), but only for compact, repair and recreating a missing index file.

If nobody still sees this slowdown in a backup on a current release, I think this can be closed.
