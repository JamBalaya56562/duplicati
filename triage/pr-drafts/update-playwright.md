Branch: `chore/update-playwright` (from master 922a7c73750fd04295ed3bae8ebc3f8832ab227b)
Title: Update Playwright to 1.64.1
Merge order: no conflict with `ci/node-26` or `chore/update-dev-style-tools` (checked each and all three together with jj). Best merged together with or after `ci/node-26`, which moves the Playwright job to Node 26, where the warning appears.

## Summary

On Node 26, every Playwright run printed:

```
(node:21448) [DEP0205] DeprecationWarning: `module.register()` is deprecated. Use `module.registerHooks()` instead.
```

Playwright 1.56.1 registers its test loader with `module.register()`, which Node 26 deprecates. Playwright switched to `module.registerHooks()` where Node has it in [microsoft/playwright#40891](https://github.com/microsoft/playwright/pull/40891) (for [microsoft/playwright#40868](https://github.com/microsoft/playwright/issues/40868)), first released in 1.61.0.

This updates `@playwright/test` (and `playwright`, `playwright-core`) in `package-lock.json` from 1.56.1 to the current 1.64.1. `package.json` keeps `"@playwright/test": "^1.48.0"`, which already allows it.

The breaking changes listed in the release notes from 1.57 to 1.64 remove old APIs (`page.accessibility`, `_react` / `_vue` selectors, `:light`, the `devtools` launch option, `Locator.ariaRef()`, the `handle` option of `exposeBinding`, `videosPath` / `videoSize`, the svelte component testing package), change the `junit` reporter, and forward `screen` from device descriptors. None of these is used in `playwright.config.ts` or `playwright-tests/`. 1.64 needs Node 20 or later, which the CI job has. The CI step `npx playwright install --with-deps` stays the same; it installs the browsers of the new version.

Commit: [a54050912105ff25963e6394b35cf8e2c1bdfc1e](https://github.com/JamBalaya56562/duplicati/commit/a54050912105ff25963e6394b35cf8e2c1bdfc1e)

## Testing

On Windows, against a local server started like the CI job:

- `DEP0205` lines in the Playwright output on Node 26.12.0: 2 with 1.56.1, 0 with 1.64.1 (four runs).
- `ngaxAuthRefresh.spec.ts` (2 tests): passed in every run on Node 20.20.2 and Node 26.12.0.
- `backupRestore.spec.ts`:
  - Against a server from master it failed on both Node versions at the known race where two destination tests run at once after "Create folder" ("Test connection failed ... being used by another process"; fixed in `fix/connection-test-unique-file`). The same failure happened with 1.56.1.
  - Against a server with that fix, it passed in two of four runs (Node 20 and Node 26 once each). The other two failures were also in the test flow and not in Playwright: a second "Create folder" prompt from the same Continue race in the web UI, and the backup not being saved because the test leaves the page right after pressing Submit (the `POST /api/v1/backups` request in the trace has no response). The Submit issue is addressed in a separate PR.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
