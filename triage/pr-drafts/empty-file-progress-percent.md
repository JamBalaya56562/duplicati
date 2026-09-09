Fixes #5093

## What happens

On the home page of the old UI (`ngax`), the progress of the current file is computed in `templates/home.html` as `1 - (size - offset) / size`. For an empty file that is 0 divided by 0, which is `NaN`:

- the bar's style becomes `width: NaNpx`, which the browser ignores, so the bar shows full;
- the `number` filter turns `NaN` into an empty string, so the text is a percent sign without a number.

That is what the issue shows.

## The change

When the file size is 0, the progress is taken as 1, so an empty file shows 100%, matching the full bar it already showed. The reporter preferred 100% over 0. Files with a size are computed as before.

## Checked

There is no test framework for the `ngax` scripts, so this was checked in a browser (Chromium), on the home page of a local server. The progress event on the page's scope was set to a backup that is processing one file, with the template switched between master and this branch, and the bar's text and style were read:

| Current file | Before | After |
|---|---|---|
| empty (size 0, offset 0) | text "%", style `width: NaNpx` (shown full) | text "100.00%", style `width: 200px` |
| size 1000, offset 250 | text "25.00%", style `width: 50px` | the same |

The new UI computes the same ratio in its status bar and shows "NaN%" for an empty file; that is fixed separately in ngclient.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
