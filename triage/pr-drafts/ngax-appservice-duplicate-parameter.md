# Remove the duplicate parameter from the old UI's AppService

Fixes #5465

`Localizations/webroot/extract.sh` reports `Error parsing scripts/services/AppService.js`. The cause is the first line of the file, which lists `$cookies` twice:

```js
backupApp.service('AppService', function ($http, $cookies, $q, $cookies, DialogService, appConfig) {
```

Browsers accept a repeated parameter name in a non-strict script, so the UI works. angular-gettext-tools parses the files as modules with `@babel/parser`, which rejects it with "Argument name clash", so the extraction skips the file.

The change ([b464fc0a](https://github.com/duplicati/duplicati/commit/b464fc0aeffa3494f5ebe5d0c056178eb11b60cb)) removes the second `$cookies`. AngularJS injects services by parameter name, so the factory still receives the same `$cookies`.

Checked with angular-gettext-cli 1.2.0 (angular-gettext-tools 2.5.3, @babel/parser 7.29.12):
- Before: `Error parsing scripts/services/AppService.js`, 145 files read.
- After: no error, and the extracted `.pot` is identical, because AppService.js has no translatable strings.
- The Playwright tests for the old UI (`ngaxAuthRefresh`, `ngaxPages` and others) pass on the fork: 21 of 21 in [run 41205438202](https://github.com/JamBalaya56562/duplicati/actions/runs/41205438202) (Playwright UI tests job)

The issue also mentions that changes to the Strings.cs files did not seem to show up. Those are extracted by `Localizations/duplicati/extract.sh`, which works on current master: run with xgettext 0.23.2 on a copy of [d2f77cc8](https://github.com/duplicati/duplicati/commit/d2f77cc8eee7), it extracts 1630 strings, including ones added to Strings.cs this month, and none of them contains `\r`. The committed `localization.pot` has 1225 because it is only regenerated when strings are pushed to Transifex.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
