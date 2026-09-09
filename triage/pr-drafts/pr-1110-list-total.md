Following #7735, which fixed the same counts for `SearchEntriesAsync`, this fixes them for `ListFolderAsync` and `ListFileVersionsAsync` in `LocalListDatabase`:

- A first page that was exactly full was taken to hold every result (`results.Count <= limit`), so the total was the page size, and the number of pages was 1.
- Without a limit (`long.MaxValue`), `(totalCount + limit - 1) / limit` overflowed and the number of pages was 0.
- On later pages, which report -1 for the total, the number of pages depended on the page size.

## The change

- Only a page that is not full (`results.Count < limit`) is taken to hold all the results. A full page counts the total with the count query, as a larger first page already did.
- The number of pages comes from the new `GetTotalPages`: -1 when the total is not counted, 0 for no results, and no overflow for `long.MaxValue`. `SearchEntriesAsync` had the same calculation written out since #7735, and now calls it too.

## Testing

New tests in `DirectListHandlerTests` (4 results):

| test | master | this branch |
|---|---|---|
| `ListFolder_FirstPageReportsTheTotalAsync` (page sizes 1, 3, 4, 5) | **fail** | pass |
| `ListFileVersions_FirstPageReportsTheTotalAsync` (page sizes 1, 3, 4, 5) | **fail** | pass |
| `ListFileVersions_FirstPageTotalUsesTheVersionsAsync` | **fail** | pass |

The master column was measured on master when the branch was written.

Rebased on master [d6dcdd0c7](https://github.com/duplicati/duplicati/commit/d6dcdd0c734f99d9c5101e55cd3dc287b191e5e9), on Windows: `DirectListHandlerTests`, 37 passed, including the search tests. No warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
