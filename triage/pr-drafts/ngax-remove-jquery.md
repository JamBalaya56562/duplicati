Title: Remove jQuery and jQuery UI from the ngax UI

## Summary

The legacy ngax UI bundles jQuery 2.1.4 and jQuery UI 1.10.3, both old versions with known security issues. It uses them in only a few places, so this replaces those places with standard DOM calls and removes both libraries. AngularJS then uses its built-in jqLite.

- `scripts/menu.js`: the mobile menu and the five three-dot menus were opened through delegated jQuery click handlers (`$('body').on('click', selector, …)`). jqLite does not support delegated selectors, so these now use `addEventListener`, `closest` and `classList`. A click anywhere else still closes them.
- `scripts/controllers/AppController.js`: drops two `removeClass` calls for `#contextmenu_pause` and `#contextmenulink_pause`. These elements no longer exist; they were removed from the page in [e4d8058cd31f4a50aac17817a86d186b102c5144](https://github.com/duplicati/duplicati/commit/e4d8058cd31f4a50aac17817a86d186b102c5144).
- File pickers (`addoredit.html`, `restore.html`, `backends/file.html`): an inline script made them resizable with jQuery UI. This is now done in CSS with `resize: both; overflow: auto;` on `.resizable` in `less/base.less`. `styles/default.css` and `styles/dark.css` were rebuilt with the `build:style` steps, and the only change in the built files is these two properties. The resize handle in the corner now looks like the browser's own handle, not the jQuery UI one.
- `templates/about.html`: the backend, compression and encryption module lists were inside a `translate` element. When the language is set at startup, angular-gettext rebuilds that content, and the original `ng-repeat` is left detached from the page. When the system info then loads, it tries to insert rows there. jQuery ignored those inserts, but jqLite throws `TypeError: Cannot read properties of null (reading 'insertBefore')` (3 console errors on the About page). Only the label is translated now: `<li><span translate>Backend modules:</span> <p ng-repeat…>`. The page shows the same text and no errors.
- `index.html` no longer loads `jquery.min.js` or `jquery-ui.min.js`, and those files (and `jquery.min.map`) are removed.

**Translations:** the three about-page strings change from `Backend modules: <p …ng-repeat…>…</p>` (and the same for compression and encryption) to `Backend modules:`, `Compression modules:` and `Encryption modules:`. The `.po` files and Transifex are not changed here, so these three labels will show in English until they are translated again.

The login and sign-in pages are handled separately in the PR for #4992. `thirdparty/jQuery` is left as is, because the login pages on master still bundle jQuery.

Commit: [ab03b85786b373554ddca7a368d628a786bda98c](https://github.com/JamBalaya56562/duplicati/commit/ab03b85786b373554ddca7a368d628a786bda98c)

Related to #4992

## Testing

The server was run on Windows, once from master and once with this change, and both were tested the same way.

- New `playwright-tests/ngaxWithoutJquery.spec.ts`, with 5 tests:
  - ngax loads without jQuery and logs no console errors.
  - The mobile menu opens, and a click elsewhere closes it.
  - The three-dot menu on the destination step opens, closes and closes on an outside click. Its "Import Destination URL" item opens the dialog, and Cancel closes it.
  - A folder in the source tree can be expanded (`Computer` → first drive or `/`).
  - Dragging the corner of a file picker changes its size.

  On master, only the "without jQuery" test fails; the other 4 pass. With the change, all 5 pass. With the change but the old `menu.js`, all 5 fail. With only the old CSS, the resize test fails (the height stays at 200px).
- `ngaxAuthRefresh.spec.ts` and the ngax page tests from the pending `ngaxPages.spec.ts`: 11 passed both before and after. Before the about.html change, `#/about` failed with the 3 errors above.
- Screenshots of 14 views (home, add start and steps 1–5 with a three-dot menu open, restore start, settings, about, log, command line, import, and the mobile menu) were compared before and after. 12 are byte-identical. The other 2 differ only in the 10×10 px resize-handle corner of the file picker. On the About "System info" tab, the module list text is identical and its rows are pixel-identical.
- stylelint reports 223 problems both before and after; none are on the new lines.
- No C# files are changed, so there are no new build warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
