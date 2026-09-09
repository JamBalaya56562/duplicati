A Drime backup fails at the start, while listing the destination folder, although every entry was listed (#7474):

```
DrimePaginationException: Terminal page 1 reported total=2010, but window 5 contained 12 unique IDs.
```

Thanks to @machpa for the log with the listing progress.

## Cause

A folder is listed in windows of 20 pages, and each window after the first starts at the creation date of the last entry of the previous window (#7318). When the last page of a window is reached, the number of entries in the window is compared with the `total` that Drime reports for it.

In the log, windows 1 to 4 listed 3997 entries, and page 1 of window 5 brought the count to 4008, the same as the folder count. That page was the last one, and Drime reported `total=2010` for a window with 12 entries. So for a window with the `created_at` filter, the total is not the number of entries in it. 2010 is 4008 minus the 1998 entries of the first two windows, but I could not confirm with the Drime API what the total counts. An earlier run failed the same way on page 1 of window 5 (`total=1011`, 12 entries).

This check comes before the check of the folder count, so the listing failed even though it was complete.

## The change

The total is checked only for the first window, which has no filter. The other checks stay as they are:

- a repeated page fails,
- an entry before the date of the window fails,
- the active entries must match the folder count, which is read again after the listing,

so a listing that misses entries still fails.

## Testing

`DrimePaginationTests` has a stub of the windows. I added an option that reports the size of the whole folder as the total of a filtered window, and two tests:

| test | master | this branch |
|---|---|---|
| a misreported total of a filtered window, all entries listed | **fail**: `Terminal page 2 reported total=21, but window 2 contained 2 unique IDs.` | pass |
| a misreported total, and a folder count of one more entry | fail (on the total) | pass: fails with "Trash semantics cannot be reconciled safely" |

All 23 Drime tests pass. No new warnings in the changed files.

Not tried: the Drime service itself.

Fixes #7474

🤖 Generated with [Claude Code](https://claude.com/claude-code)
