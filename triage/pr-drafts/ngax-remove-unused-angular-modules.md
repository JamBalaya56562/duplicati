Related to #4992

## Summary

`ngax/index.html` loads `angular-loader`, `angular-animate`, `angular-resource` and `angular-touch`, but nothing uses them:

- `backupApp` depends on `ngRoute`, `dotjem.angular.tree`, `ngCookies`, `ngSanitize`, `gettext` and `ngclipboard`. No module depends on `ngAnimate`, `ngResource` or `ngTouch`.
- No script or template uses `$resource`, `$swipe`, `$animateCss`, `ng-swipe-*` or `ng-animate`.
- `angular-gettext` injects `$animate`. That service is part of the AngularJS core (`angular.min.js`), not of `ngAnimate`, so it is still there.
- No other page, build script, installer list or `thirdparty` entry names these files. `thirdparty/AngularJS` covers AngularJS as a whole and does not list the modules.

This removes the four `<script>` tags and the four `.min.js` files with their source maps. It follows #7831 and #7839, which removed jQuery and the other unused libraries from ngax.

## Testing

- On the current master with this change, a search for the file names, the module names and the services above in `Duplicati/`, `ReleaseBuilder/`, `thirdparty/`, `package.json` and `playwright-tests/` finds only `angular/errors.json`, the error message list that comes with AngularJS.
- The server was run on Windows from master and from this change, and both were tested the same way: `ngaxAuthRefresh.spec.ts` and the ngax page tests (`ngaxPages.spec.ts`), 11 passed both before and after. Screenshots of 10 views (home, add start, add, restore start, settings, about, log, command line, import, and home at mobile width) are byte-identical before and after, and neither run logged a console error.
- On top of the jQuery removal and the unused library cleanup, the same tests passed and no console error was logged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
