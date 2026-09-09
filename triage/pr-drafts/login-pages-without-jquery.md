Title: Drop jQuery from the login and signin pages

## Summary

`/login.html` (which the legacy ngax UI sends you to) and `/signin.html` (which opens with a sign-in token) each bundled their own copy of jQuery 2.0.3, the version reported in #4992. The two page scripts used jQuery only for `$(document).ready`, `.on('submit')`, `$.ajax` and `.val()`, so this replaces those calls with plain DOM calls and `fetch` and removes jQuery from both pages:

- `login.js` and `signin.js`: `DOMContentLoaded`, `addEventListener('submit')`, `fetch` and `.value`. A small `postJson` helper in each file reports errors the same way the old `.fail` handler did. It uses the server's JSON `Error` when there is one, and the HTTP status text otherwise. A network failure shows `error`, which is what jQuery reported.
- `login.html` and `signin.html` no longer load jQuery, and `login/jquery-2.0.3.min.*` and `signin/jquery-2.0.3.min.*` are deleted.
- One small difference: the submit handler now always cancels the browser's own form post. Before, a second click while a request was still running returned without cancelling it, so the browser also posted the form to the page itself.

**Note for OEM builds:** `login.html` also loads `oem/root/login/oem.js`. The file in this repository is a one-line placeholder, but an OEM build that replaces it with its own script using `$` or `jQuery` will now get a "$ is not defined" error on the login page. Such a script needs to be rewritten without jQuery, or it has to load jQuery itself.

The ngax app itself still loads its own jQuery 2.1.4 (`ngax/scripts/libs/jquery.min.js`), which is separate from these pages and is not changed here.

Commit: [79f7553a4e1b40b0b1baee2fc17f220adde971ce](https://github.com/JamBalaya56562/duplicati/commit/79f7553a4e1b40b0b1baee2fc17f220adde971ce)

Fixes #4992

## Testing

The server was run on Windows, once from master and once with this change, and both were tested the same way.

- New `playwright-tests/loginPages.spec.ts`, with 7 tests:
  - Each page runs without jQuery, hides the no-JavaScript warning and logs no console errors.
  - A wrong password shows "Login failed: Failed to log in".
  - An error reply that is not JSON shows its status text ("Login failed: Internal Server Error").
  - A correct password signs in and stores the refresh nonce.
  - A bad sign-in token shows "Signin failed: …".
  - A successful refresh on the sign-in page moves on.

  On master the two "without jQuery" checks fail (`window.jQuery` is a function) and the other 5 pass, so the messages and the flow are the same with jQuery and with `fetch`. With the change, all 7 pass.
- A login request aborted by the browser (as a network failure) shows "Login failed: error" both before and after the change. This was checked once by hand and is not part of the spec.
- Screenshots of `login.html` and `signin.html` (1000×700) are byte-identical before and after the change.
- `ngaxAuthRefresh.spec.ts`, together with the ngax page tests from the pending `ngaxPages.spec.ts`, which log in through `login.html`: 11 passed both before and after the change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
