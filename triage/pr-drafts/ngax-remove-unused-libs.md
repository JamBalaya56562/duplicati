Related to #4992

## Summary

Removing jQuery and jQuery UI from ngax (#7831) left two files that `index.html` still loads but nothing uses:

- `scripts/libs/modal.min.js` (angular-modal 0.5.0) and its source map. It only defines the `btford.modal` module, and no ngax module depends on it (`backupApp` lists `ngRoute`, `dotjem.angular.tree`, `ngCookies`, `ngSanitize`, `gettext` and `ngclipboard`). ngax shows its dialogs with its own `DialogService` and the `modal-dialog` markup in `index.html`.
- `styles/smoothness/jquery-ui.min.css` and its 15 images in `styles/smoothness/images/`. This is the jQuery UI theme. It styles only jQuery UI widgets (`ui-*` classes), and no template, script or `.less` file uses those classes.

Both `<script>`/`<link>` tags are removed from `index.html`, and the files are deleted. Nothing else refers to them: on the current master with this change, a search for `modal.min`, `btford`, `smoothness` and `jquery-ui` in `Duplicati/`, `ReleaseBuilder/`, `thirdparty/`, `package.json` and `playwright-tests/` finds nothing. `thirdparty/` has no license entry for either of them.

## Testing

The server was run on Windows, once with the jQuery removal (#7831) and once with this change, and both were tested the same way.

- `ngaxAuthRefresh.spec.ts`, `ngaxWithoutJquery.spec.ts` and the ngax page tests (`ngaxPages.spec.ts`): 16 passed both before and after. On a freshly started server, the first run of the three-dot menu test sometimes logs `TypeError: Cannot read properties of undefined (reading 'length')` from `sourceFolderPicker.js`. This happens before and after this change, and also on master with jQuery, whenever `/backupdefaults` answers after the file system list. It is an existing race and is not related to this change.
- Screenshots of 16 views (home, add start and steps 1–5 with a three-dot menu open, the "Import URL" dialog, restore start, settings, about and its Libraries tab, log, command line, import, and the mobile menu) are byte-identical before and after. Neither run logged a console error.
- Rebuilding `styles/default.css` and `styles/dark.css` from the `.less` files gives the committed files unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
