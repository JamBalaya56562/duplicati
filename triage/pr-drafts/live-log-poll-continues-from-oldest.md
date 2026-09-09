Fixes #5572

## What happens

The web UI polls the live log every 3 seconds with `/api/v1/logdata/poll?id=<highest ID seen>&pagesize=100`, and carries on from the highest ID in each answer.

`LogWriteHandler.AfterID` returned the newest `pagesize` entries when more than that had arrived since `id` ("Return the <page_size> newest entries", since 2018). The client then continued from the highest of them, so every entry before that page was never shown.

A database recreate at Verbose writes more than 100 lines in 3 seconds, which is where #5572 sees gaps in its `volume N of M` lines.

## The change

- A poll that continues from an ID it has seen (`id > 0`) gets the **oldest** `pagesize` entries after it. The next polls return the rest, so nothing is skipped.
- A poll that has seen nothing yet (`id <= 0`) still gets the newest entries, so opening the live log shows what is happening now, not the oldest of up to 5000 kept entries.

The web UI needs no change. It reverses each page and puts it in front of what it has, which keeps the lines in order when the pages come oldest first.

## Red to green

`Duplicati/UnitTest/LiveLogPollingTests.cs` (new). It polls `AfterID` the way the web UI does (page size 100, continuing from the highest ID seen) until caught up.

| Test | Before | After |
|---|---|---|
| 250 lines arrive between two polls | **red**: 100 received (151-250), 1-150 skipped | green: all 250, in order |
| A first poll with 250 lines kept | green: the newest 100 | green (guard) |

`ServerMetadataEndpointsReturnData_Async` (which polls with `id=0`) and `ServerBackupLifecycle_Async` pass.

## Not covered

- A client that has not received any entry yet keeps polling with `id=0`. If more than a page arrives before its first non-empty answer, it still gets the newest page for that first answer.
- The buffer keeps 5000 entries while the live log is active. A client that falls further behind than that still misses the entries that were overwritten.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
