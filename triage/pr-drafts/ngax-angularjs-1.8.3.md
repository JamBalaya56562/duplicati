## Summary

ngax bundles AngularJS 1.4.3 from 2015. This updates it and the three modules ngax uses (`angular-route`, `angular-cookies`, `angular-sanitize`) to 1.8.3, the last AngularJS release. The files are the `.min.js` and `.min.js.map` files from the npm packages. Their sha512 matches the registry `integrity` value.

AngularJS reached its end of support in January 2022, and 1.8.3 still has known issues that will not be fixed. This update does not change that, but it removes the issues that were fixed between 1.4.3 and 1.8.3.

ngax needed these changes for 1.8.3:

- **URLs:** 1.6 changed the hash prefix from `#/` to `#!/`, so every `#/page` link and bookmark went to the home page. `$locationProvider.hashPrefix('')` keeps the `#/page` URLs.
- **OAuth AuthID:** 1.6 dropped `JSON_CALLBACK` and only allows JSONP to trusted resource URLs. The request that waits for the AuthID was refused, failed silently and was retried until it gave up, so OAuth destinations (Google Drive, OneDrive, Dropbox and others) never got an AuthID. It now uses `jsonpCallbackParam: 'callback'` and `$sce.trustAsResourceUrl`. The service URL is the default OAuth server or the one set with `--oauth-url`, as before.
- **Unhandled rejections:** 1.6 logs a rejected promise without a rejection handler as a console error. Many ngax requests have no rejection handler. With all API calls answering 500, the About page logged one such error. `$qProvider.errorOnUnhandledRejections(false)` keeps the earlier behaviour for all requests, including the ones that only fail after a user action.
- **angular-gettext:** the bundled angular-gettext calls `angular.lowercase`, which 1.7 removed. Without it the `translate` directive threw, and no page rendered. `app.js` now provides it when it is missing. Updating angular-gettext would remove the need for this.
- **Menu button:** 1.4.3 wrapped the translated "Menu" label in a `<span>`, and the layout for widths of 400px or less hides `.menubutton span` to show only the icon. 1.8.3 no longer adds that span, so "MENU" showed next to the icon. The span is now in `index.html`. No CSS is changed.

Also:

- The unused 1.4.3 files `angular-aria`, `angular-messages` and `angular-message-format` are removed. Nothing loads them. So are `version.json`, `version.txt` and `errors.json`, which nothing reads.
- The AngularJS script tags get `?v=1.8.3`, so browsers do not keep the cached 1.4.3 files.
- `thirdparty/AngularJS/License.txt` is now the license file shipped with 1.8.3.

Commit: [f6a51b435ffe8198bb6a9387782afed0909afd3c](https://github.com/JamBalaya56562/duplicati/commit/f6a51b435ffe8198bb6a9387782afed0909afd3c)

## Testing

The server was run on Windows, and the same Playwright tests were run before and after.

- On the current master (after #7843) with this change: all 21 ngax Playwright tests in `playwright-tests/` pass, including `ngaxPages`, `ngaxSourcePicker`, `ngaxSourcePickerNames`, `ngaxIpv6Server` and `ngaxEditKeepsMetadata`, which were merged after the comparison runs below.

- New `playwright-tests/ngaxOAuth.spec.ts`. It selects Google Drive as the destination and clicks "AuthID". It answers the OAuth service's requests with a route, and expects the AuthID field to be filled.
  - Passes with 1.4.3.
  - Fails with 1.8.3 when only the JSONP call is left unchanged: the field stays empty.
  - Passes with this change.
- `ngaxAuthRefresh.spec.ts`, `ngaxWithoutJquery.spec.ts`, `ngaxOAuth.spec.ts` and the ngax page tests (`ngaxPages.spec.ts`): all 18 pass both before and after.
- With only the library files replaced, 13 tests failed:
  - `angular.lowercase is not a function`
  - pages that never rendered
  - `#/` links that went to the home page
- With all API calls answering 500, each page was checked for "Possibly unhandled rejection" console errors. There was 1 (on the About page) before the `$qProvider` change, and 0 after it.
- Screenshots of 9 views at desktop width and the same 9 views at 400px width (home, add start, add, restore start, settings, about, log, command line, import) are byte-identical between 1.4.3 and this change. Neither run logged a console error.
- No C# files are changed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
