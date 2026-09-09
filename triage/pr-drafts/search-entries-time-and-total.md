# Return the version time and the total of the first page from search

Branch: `fix/search-entries-time-and-total`, one commit on master 6dee7d94. Do not add `Fixes duplicati/ngclient#394`; the ngclient PR closes it.

## Body

`POST /api/v2/backup/search` had two problems, found while adding a search over all versions to the new UI:

1. **The time of every match was in year 1.** `LocalListDatabase.SearchEntriesAsync` read `Fileset.Timestamp`, which is stored as Unix seconds, as ticks. With two versions from 2026-11-07T11:17:07Z and 11:17:04Z, search returned `0001-01-01T00:02:59.4050227Z` and `0001-01-01T00:02:59.4050224Z`. It now uses `ParseFromEpochSeconds`, as list-filesets does. `LastModified` is stored as ticks and is unchanged.
2. **A full first page reported a total of its own rows.** The total was only counted when `results.Count <= limit`, which is always true with a `LIMIT`. With two matches and a page size of 1, page 0 reported `Total: 1, Pages: 1`, so a client had no next page. The total is now counted when the first page is full, with the same filter, folder scope and version limit. A page that is not full still uses its row count.

The pages are computed from the total in the same function. Two more cases there were wrong and are fixed with it:
- Later pages report `-1` for the total, as before. Their `TotalPages` was `(-1 + limit - 1) / limit`, so `-1` with a page size of 1 and `0` otherwise. It is now `-1` whenever the total is unknown.
- A search without a limit (`limit = 0`, which becomes `long.MaxValue`) overflowed when rounding up. With four matches it reported 0 pages. It now reports 1.

The v2 endpoint computes `PageInfo.Pages` from the total itself, so later pages there still report `Pages` as `ceil(-1 / PageSize)`; that is unchanged.

## Testing

New tests in `DirectListHandlerTests`, on a backup with `a/report.txt`, `b/report.txt` and `notes.txt` in two versions:

| test | master | this branch |
|---|---|---|
| `SearchEntries_TimeIsTheTimeOfTheVersionAsync` (each row's time equals the list-filesets time of its version, UTC, whole seconds) | **fail**: `Expected: 2026-11-07 12:07:00 But was: 0001-01-01 00:02:59.405322` | pass |
| `SearchEntries_FirstPageReportsTheTotalAsync(1,4,4)` and `(3,4,2)` (full first page) | **fail**: total 1 and 3 | pass |
| `SearchEntries_FirstPageReportsTheTotalAsync(4,4,1)` and `(5,4,1)` | **fail**: the search without a limit reported 0 pages | pass |
| `SearchEntries_FirstPageTotalUsesTheFilterFolderAndVersionsAsync` (all `*.txt`, one folder, latest version only, no match) | **fail**: total 1 instead of 6 | pass |

All 28 `DirectListHandlerTests` pass on Windows. No new warnings in the changed files.

On a Debug server with a separate data folder, two backups of `report.txt`, then `search` with `"Filters":["*report.txt"],"Version":null,"Time":null`:
- list-filesets: version 0 `2026-11-07T12:09:33Z`, version 1 `2026-11-07T12:09:28Z`; search returns the same times for the same versions.
- `PageSize: 1`, page 0: `{"Page":0,"PageSize":1,"Total":2,"Pages":2}` with one row; page 1: `{"Page":1,"PageSize":1,"Total":-1,"Pages":-1}` with the other row.

Related to duplicati/ngclient#394

🤖 Generated with [Claude Code](https://claude.com/claude-code)
