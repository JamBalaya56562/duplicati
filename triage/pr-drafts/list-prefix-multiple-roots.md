## What happens

For a backup from several drives, or from a drive and a network share, the root of the restore tree took about 30 seconds per drive to appear, and an extra, empty root appeared below the real ones.

The root comes from the largest-prefix listing (`list-prefix-only`, `GET /api/v1/backup/{id}/files?prefix-only=true`). Such a backup has no common prefix, so `LocalListDatabase.FileSets.GetLargestPrefixAsync` finds the prefix of each drive or share on its own, by calling itself with that root.

Since the listing became asynchronous in [`179d1ceb`](https://github.com/duplicati/duplicati/commit/179d1ceb479fc0a0330c42ca4021d7f2accee0f0), two things changed in that branch:

- The paths are enumerated lazily, so the reader over them is still open while each root is looked into. Each look drops its temporary table when it is done, and on the same connection that `DROP TABLE` waits for the command timeout (30 seconds) in `SqliteDataReader.NextResult`. The failure is then swallowed by `FilteredFilenameTable.DisposeAsync`. A dump of a waiting server shows exactly this stack.
- After returning the roots, the method went on to return the common prefix as well, which is empty here.

The synchronous version before it (`.ToArray()` on the paths, then `return` with the roots) had neither problem.

Who sees it: the old web UI (always), and the new UI only when the server does not offer the v2 list API. With the v2 list API, the new UI lists the roots with `list-folder` instead, which does not go through this code (checked, see below).

## The change

- Read the paths into a list before looking into the roots.
- Stop after the roots have been returned.

The `Distinct()` over the per-root tasks is dropped: it compared the task wrappers, not paths, so it never removed anything.

## Red to green

`Duplicati/UnitTest/ListPrefixMultipleRootsTests.cs` (new) backs up three folders and then rewrites their paths in the local database to `Q:\srcA\`, `R:\srcB\` and `\\server\share\srcC\`. Paths on one host always share a root, so this is how the test gets several roots on any platform, and the code under test only looks at the path strings. It then lists with `list-prefix-only` and expects exactly the three roots, within 15 seconds.

| | Before | After |
|---|---|---|
| Windows | **red**: extra `""` root, the test took 1 m 41 s | green, 11 s |
| Linux (WSL) | **red**: extra `""` root, 1 m 40 s | green, 8 s |

Checked by hand as well, with two drives made with `subst`:

| | Before | After |
|---|---|---|
| `prefix-only=true` over the API | 60.4 s, `Q:\srcA\`, `R:\srcB\` and `""` | 0.47 s (4.7 s on the first call), `Q:\srcA\` and `R:\srcB\` |
| Old UI restore page | tree after about a minute, with an empty third root | not opened again; it makes the same call as the row above |
| New UI, v2 list API offered (the default) | uses `POST /api/v2/backup/list-folder`, 319 ms, no empty root: not affected | unchanged |
| New UI, v2 list API disabled (`--webservice-disable-api-extensions`) | `prefix-only=true` took 62.2 s, empty root shown | 407 ms, two roots |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
