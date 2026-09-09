Title: Show folder names in the ngax source list when the system info is late

## Summary

In the ngax backup editor, the source list can show a special folder by its raw, lowercased path, for example `%home%`, instead of its name, `Home`.

The source picker keeps the names of the `%...%` folders (Home, Documents and so on) in `displayMap`. Its keys come from `compareablePath`, which adds the directory separator and lowercases the path unless the file system is case-sensitive. Both of these come from the system info. When the folder list (`/filesystem`) arrived before the system info, `scope.dirsep` was still `null`. The keys were then built as `%home%null`. When the separator arrived, the list was built again and looked for `%home%\`, found no name, and showed the raw path.

The picker now keeps the `%...%` folders from the folder list and adds their names to `displayMap` once more when the directory separator arrives, before it rebuilds the list. Names that are already right are written again unchanged.

Commit: [f3fbd311468717bb83ef811afaf4e625ba0a3fc9](https://github.com/JamBalaya56562/duplicati/commit/f3fbd311468717bb83ef811afaf4e625ba0a3fc9)

I could not find an issue for this.

## Testing

- New `playwright-tests/ngaxSourcePickerNames.spec.ts`. It holds back the `/systeminfo` answer until the source picker has its folder list. It sets the backup's source to `%HOME%`, and expects "Source data" to list `Home`.
  - On master it fails 3 out of 3 runs, showing `%home%`.
  - With the fix it passes 3 out of 3 runs.
- `ngaxAuthRefresh.spec.ts` and the ngax page tests from the pending `ngaxPages.spec.ts`: 11 passed with the fix.
- Screenshots of 9 views at desktop width, at 400px width and in German, 27 in all, are byte-identical with master. One run showed a 12-pixel difference on the border of a text field on the import page, which has no source picker. A second run with the same code matched master exactly.
- Merged with the fix for a source picker error when the backup defaults load late ([c0640bf67e278d9ec5f860fae36ccb398ee6e238](https://github.com/JamBalaya56562/duplicati/commit/c0640bf67e278d9ec5f860fae36ccb398ee6e238)), both picker tests pass 6 out of 6 runs. The same holds on top of the pending AngularJS 1.8.3 and angular-gettext updates. Without this fix, the test from that branch showed `%home%` in 1 of 6 runs on master and in 4 of 6 runs with AngularJS 1.8.3.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
