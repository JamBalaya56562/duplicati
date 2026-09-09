Branch: `ci/node-26` (from master 7cdde15855229eed3c2da0690a3848522aaff55b)
Title: Run the Playwright job on Node 26
When to open: after Node 26 becomes LTS on 2026-10-28.
Merge order: no conflict with `chore/update-dev-style-tools` or `ci/check-ngax-css-build` (checked all combinations with jj). `ci/check-ngax-css-build` adds `.github/workflows/ngax-styles.yml` with `node-version: 20`; whichever of the two merges second should also set that workflow to 26.

## Summary

The Playwright job is the only place in the repository that picks a Node version (`node-version: 20` in `tests.yml`). Node 20 reached its end of life on 2026-04-30. Node 26 was released on 2026-05-05 and becomes LTS on 2026-10-28 (maintenance from 2027-10-20, end of life 2029-04-30, per [nodejs/Release](https://github.com/nodejs/Release/blob/main/schedule.json)).

This sets the job to Node 26 and updates `@types/node` from `^24.10.0` to `^26.6.5` to match (the lockfile changes only `@types/node` and `undici-types`).

None of the tools in `package.json` limit the Node version from above: `@playwright/test` 1.56.1 needs >= 18, `stylelint` 16.26.1 >= 18.12.0, `less` 4.2.0 >= 6, `postcss` and `autoprefixer` >= 14, `postcss-cli` 11 >= 18 (12 needs >= 22). The ReleaseBuilder runs `npm ci` for the web UI packages with whatever npm the build machine has, so it is not affected.

Commit: [fd2c7198ca5fad98dc426c80de9424b06beb4ac8](https://github.com/JamBalaya56562/duplicati/commit/fd2c7198ca5fad98dc426c80de9424b06beb4ac8)

## Testing

Compared Node 20.20.2 (old lockfile) and Node 26.12.0 (new lockfile) on Windows, each after a clean `npm ci`:

- `npm ci`: no warnings on either version.
- ngax CSS (`lessc` + `postcss`, the build part of `build:style`): byte-identical between Node 20 and 26, and identical to the committed `dark.css` / `default.css`. The build log and the changes `lint:style-fix` makes are identical too.
- `lint:style` on the `.less` sources: 223 problems on both versions, identical output.
- Playwright (`npx playwright test`, server published from this branch and started like the CI job, empty data folder for each run): the three existing tests pass on both versions. Playwright 1.56.1 prints a `DEP0205` deprecation warning for `module.register()` on Node 26; it does not affect the run.
  - The machine was under heavy load from other builds, and `backup and restore flow` sometimes failed on both versions: either the 120 s test timeout, or a Windows-only `Test connection failed ... being used by another process` when the File backend deletes its access test file. With `--timeout=600000`, Node 20 and Node 26 each ran twice alternately; both versions passed, and the one failure (on Node 26) was the same file-lock dialog seen on Node 20 earlier. Neither cause depends on the Node version, and the CI job runs on Linux.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
