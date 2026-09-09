Title: Update angular-gettext in ngax to 2.4.2

(Open after the PR for `chore/ngax-angularjs-1.8.3` is merged; this branch is built on it.)

## Summary

The angular-gettext bundled with ngax calls `angular.lowercase`, which AngularJS 1.7 removed. The AngularJS 1.8.3 update therefore defined `angular.lowercase` in `app.js`. This updates angular-gettext to 2.4.2, its latest release, which no longer calls it, and removes that workaround again.

- `scripts/libs/angular-gettext.min.js` is `dist/angular-gettext.min.js` from the npm package `angular-gettext@2.4.2`. Its sha512 matches the registry `integrity` value.
- ngax uses only `gettextCatalog.getString`, `setStrings` and `setCurrentLanguage`, the `translate` directive and the `translate` filter. 2.4.2 has all of these. The compiled translations (`angular-gettext-cli_compiled_js_output.js`) are unchanged.
- The script tag gets `?v=2.4.2`, so browsers do not keep the cached file.
- `thirdparty/angular-gettext/License.txt` is now the license file shipped with 2.4.2.

Commit: [d374ac689d5b548a974afdf85f22c2d1aa6b73bd](https://github.com/JamBalaya56562/duplicati/commit/d374ac689d5b548a974afdf85f22c2d1aa6b73bd)

## Testing

The server was run on Windows, and the same Playwright tests were run before and after.

- `ngaxAuthRefresh.spec.ts`, `ngaxWithoutJquery.spec.ts`, `ngaxOAuth.spec.ts`, `ngaxSourcePicker.spec.ts` and the ngax page tests from the pending `ngaxPages.spec.ts`: 19 passed. `ngaxSourcePicker.spec.ts` is flaky on this base for a reason unrelated to this change: the source list sometimes shows `%home%` instead of `Home`. This also happens on AngularJS 1.4.3.
- Screenshots were taken of 9 views (home, add start, add, restore start, settings, about, log, command line, import) in three ways: in English at desktop width, in English at 400px width, and in German (`ui-locale=de`) at desktop width. That is 27 screenshots.
  - They are byte-identical before and after this change.
  - They are also byte-identical with the same views on AngularJS 1.4.3 before the AngularJS update.
  - The German ones show the German texts (for example "Einstellungen" and "Keine geplanten Aufgaben").
  - No run logged a console error.
- No C# files are changed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
