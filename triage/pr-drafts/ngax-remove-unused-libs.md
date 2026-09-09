Title: Remove unused angular-modal and jQuery UI theme from ngax

(Open after the PR for `chore/ngax-remove-jquery` is merged; this branch is built on it.)

## Summary

Removing jQuery and jQuery UI from ngax left two files that `index.html` still loads but nothing uses:

- `scripts/libs/modal.min.js` (angular-modal 0.5.0) and its source map. It only defines the `btford.modal` module, and no ngax module depends on it (`backupApp` lists `ngRoute`, `dotjem.angular.tree`, `ngCookies`, `ngSanitize`, `gettext` and `ngclipboard`). ngax shows its dialogs with its own `DialogService` and the `modal-dialog` markup in `index.html`.
- `styles/smoothness/jquery-ui.min.css` and its 15 images in `styles/smoothness/images/`. This is the jQuery UI theme. It styles only jQuery UI widgets (`ui-*` classes), and no template, script or `.less` file uses those classes.

Both `<script>`/`<link>` tags are removed from `index.html`, and the files are deleted. Nothing else refers to them by file name: there are no references in the templates, `.less` files, build settings, ReleaseBuilder or package file lists. `thirdparty/` has no license entry for either of them.

Commit: [feb34d9da87700795c54f1009c6a8ce51fd4d68a](https://github.com/JamBalaya56562/duplicati/commit/feb34d9da87700795c54f1009c6a8ce51fd4d68a)

Related to #4992

## Testing

The server was run on Windows, once with the jQuery removal branch ([ab03b85786b373554ddca7a368d628a786bda98c](https://github.com/JamBalaya56562/duplicati/commit/ab03b85786b373554ddca7a368d628a786bda98c)) and once with this change, and both were tested the same way.

- `ngaxAuthRefresh.spec.ts`, `ngaxWithoutJquery.spec.ts` and the ngax page tests from the pending `ngaxPages.spec.ts`: 16 passed both before and after. On a freshly started server, the first run of the three-dot menu test sometimes logs `TypeError: Cannot read properties of undefined (reading 'length')` from `sourceFolderPicker.js`. This happens before and after this change, and also on master with jQuery, whenever `/backupdefaults` answers after the file system list. It is an existing race and is not related to this change.
- Screenshots of 16 views (home, add start and steps 1–5 with a three-dot menu open, the "Import URL" dialog, restore start, settings, about and its Libraries tab, log, command line, import, and the mobile menu) are byte-identical before and after. Neither run logged a console error.
- Rebuilding `styles/default.css` and `styles/dark.css` from the `.less` files gives the committed files unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
