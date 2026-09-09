Branch: `test/ngax-playwright-pages` (from master 7cdde15855229eed3c2da0690a3848522aaff55b)
Title: Add Playwright tests for the main ngax pages and themes
Merge order: independent (adds one new file, `playwright-tests/ngaxPages.spec.ts`).

## Summary

The old UI (ngax) only had Playwright tests for the auth refresh. This adds `ngaxPages.spec.ts`:

- **Main pages** (`#/home`, `#/addstart`, `#/restorestart`, `#/import`, `#/settings`, `#/log`, `#/commandline`, `#/about`): after a login, each page is opened and checked for its heading or main element (for `#/commandline`, that the command list was loaded from the server), and the test fails on any console error or uncaught exception on the page.
- **Themes**: on the settings page, selecting the default and the dark theme (a preview; nothing is saved) loads `styles/default.css` / `styles/dark.css` and applies their colors and font (`body` color, header background, `"Clear Sans"`). The expected colors are the ones in the built CSS, so a change to the built styles that affects them shows up here.

The login uses the real login form. After a successful login the page continues to the new UI, which refreshes the login token while it loads; leaving it halfway sometimes left ngax with a token the server had already replaced, and ngax went back to the login page. The test therefore answers the navigation after the login with an empty page.

Commit: [cbe551632f2afcd1d7305e6c0c454eb8a1926f07](https://github.com/JamBalaya56562/duplicati/commit/cbe551632f2afcd1d7305e6c0c454eb8a1926f07)

## Testing

Server published from master and started like the CI job, with an empty data folder for each run (Windows):

- `ngaxPages.spec.ts` alone: 9 passed in each of four runs, two on Node 20.20.2 and two on Node 26.12.0 (alternating).
- Whole suite (`backupRestore`, `ngaxAuthRefresh`, `ngaxPages`): on Node 26, 12 passed. On Node 20, the 11 ngax tests passed and `backup and restore flow` failed at its known race (two connection tests at once after "Create folder"; a separate fix is in progress), so the new tests also pass after that test left a backup on the server.
- The tests catch breakage (changed in the published web root, then restored):
  - header background in `styles/default.css` changed from `#ededed` to `#eeeeee` → the theme test fails (`Expected: "rgb(237, 237, 237)"`, `Received: "rgb(238, 238, 238)"`)
  - the `Settings` heading in `templates/settings.html` changed → `#/settings` fails
  - `AboutController.js` throws when loaded → `#/about` fails (`Received: "About {{appname}}"`)
  - the other six tests still pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
