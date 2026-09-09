Title: Fix the ngax source picker when the backup defaults load late

## Summary

On the ngax "Add backup" page, the source folder picker builds its tree as soon as it has the folder list from `/filesystem`. The backup's sources come from a separate `/backupdefaults` request. If that answer comes after the folder list, `ngSources` is still `undefined`. `syncTreeWithLists` only checked for `null`, so it went on and threw:

```
TypeError: Cannot read properties of undefined (reading 'length')
    at syncTreeWithLists (sourceFolderPicker.js:282)
```

This changes the check from `=== null` to `== null`, so `undefined` is skipped as well. Once the defaults arrive, the existing `$watch('ngSources', syncTreeWithLists, true)` builds the source list. Nothing else was affected: the page recovered when the defaults arrived, so the only visible effect was the console error.

The other places were checked for the same mistake. `ngFilters` in the same function is already read as `scope.ngFilters || []`. `restoreFilePicker.js` already checks `ngSources == null`. The remaining reads of `ngSources` in `sourceFolderPicker.js` run only when the user clicks a tree node, not while the page loads.

I could not find an issue for this.

Commit: [053e4a561d18cf6e19dd0d8e0f2895776bc403ff](https://github.com/JamBalaya56562/duplicati/commit/053e4a561d18cf6e19dd0d8e0f2895776bc403ff)

## Testing

- New `playwright-tests/ngaxSourcePicker.spec.ts`. It holds back the `/backupdefaults` answer until the `/filesystem` folder list has arrived, and returns the defaults with `%HOME%` as the source. The server lists the home folder as `%HOME%` on every platform. The test then checks that the "Source data" node lists "Home" and that there are no console errors.
  - On master it fails 3 out of 3 runs with the `TypeError` above. "Home" is still listed there, so only the console error check fails.
  - With the fix it passes 3 out of 3 runs.
- `ngaxAuthRefresh.spec.ts` and the ngax page tests from the pending `ngaxPages.spec.ts`: 11 passed both on master and with the fix.
- Without the test, the race showed up on a freshly started server: the first visit to the add page sometimes logged the same error.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
