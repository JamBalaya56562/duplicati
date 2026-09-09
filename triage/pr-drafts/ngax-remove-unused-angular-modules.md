Title: Remove unused AngularJS modules from ngax

(Open after the PRs for `chore/ngax-remove-jquery` and `chore/ngax-remove-unused-libs` are merged; this branch is built on them.)

## Summary

`ngax/index.html` loads `angular-loader`, `angular-animate`, `angular-resource` and `angular-touch`, but nothing uses them:

- `backupApp` depends on `ngRoute`, `dotjem.angular.tree`, `ngCookies`, `ngSanitize`, `gettext` and `ngclipboard`. No module depends on `ngAnimate`, `ngResource` or `ngTouch`.
- No script or template uses `$resource`, `$swipe`, `$animateCss`, `ng-swipe-*` or `ng-animate`.
- `angular-gettext` and `angular-modal` inject `$animate`. That service is part of the AngularJS core (`angular.min.js`), not of `ngAnimate`, so it is still there.
- No other page, build script, installer list or `thirdparty` entry names these files. `thirdparty/AngularJS` covers AngularJS as a whole and does not list the modules.

This removes the four `<script>` tags and the four `.min.js` files with their source maps.

Commit: [c5e13cceb1a75bf38f4f83bcd413927e3f4546da](https://github.com/JamBalaya56562/duplicati/commit/c5e13cceb1a75bf38f4f83bcd413927e3f4546da)

## Testing

The server was run on Windows from master and from this change, and both were tested the same way.

- `ngaxAuthRefresh.spec.ts` and the ngax page tests from the pending `ngaxPages.spec.ts`: 11 passed both before and after.
- Screenshots of 10 views (home, add start, add, restore start, settings, about, log, command line, import, and home at mobile width) are byte-identical before and after. Neither run logged a console error.
- On top of the jQuery removal and the unused library cleanup, the same tests pass and no console error is logged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
