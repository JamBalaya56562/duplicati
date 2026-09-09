Branch: `chore/update-dev-style-tools` (from master 7cdde15855229eed3c2da0690a3848522aaff55b)
Title: Update postcss-cli to 12 and fix npm audit findings in the style tools

## Summary

The root `package.json` only holds the tools used to build and lint the ngax styles (`build:style`, `lint:style`) and Playwright. `npm audit` reported 15 findings (13 high, 2 moderate):

- `nanoid` < 3.3.18 ([GHSA-2v37-7h3g-55p8](https://github.com/advisories/GHSA-2v37-7h3g-55p8)), via `postcss`
- `colord` < 2.9.4 ([GHSA-2wm5-q62r-hmrv](https://github.com/advisories/GHSA-2wm5-q62r-hmrv)), via `stylelint`
- `yaml` 2.0.0 - 2.8.2 ([GHSA-48c2-rrv3-qjmp](https://github.com/advisories/GHSA-48c2-rrv3-qjmp)), via `postcss-cli` → `postcss-load-config`
- `braces` <= 3.0.3 ([GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm), no fixed version yet), via `postcss-cli` → `chokidar` 3, and via `stylelint` → `micromatch` / `fast-glob` / `globby`

This PR:

- runs `npm audit fix` (no major updates): `nanoid` 3.3.16 → 3.3.20, `colord` 2.9.3 → 2.10.0.
- updates `postcss-cli` from `^11.0.0` to `^12.0.0`. It uses `chokidar` 5 and `tinyglobby`, so the `braces` path through `postcss-cli` is gone, and `postcss-load-config` 6 no longer installs `yaml`.

`@playwright/test` and its dependencies are unchanged. No other files change.

After the update `npm audit` reports 10 high findings, all on the `braces` path through `stylelint`, which has no fixed version yet.

`postcss-cli` 12 declares `engines.node >= 22`. The Playwright job uses Node 20; `npm ci` there only prints an `EBADENGINE` warning, and the Playwright tests do not use `postcss-cli`. `build:style` itself also still works on Node 20 (see Testing).

Commit: [c6d08db939e8398badc30f147c725116a53694c7](https://github.com/JamBalaya56562/duplicati/commit/c6d08db939e8398badc30f147c725116a53694c7)

## Testing

Ran the same steps with the old and the new lockfile (`npm ci` each time, Node 24.21.0), and compared the results:

- **CSS output**: the `lessc` + `postcss` steps of `build:style` produce `ngax/styles/dark.css` and `default.css` that are byte-identical before and after (SHA-256 `9672413b…` and `3236a792…`), and byte-identical to the committed files.
  - To check that this comparison would catch a change in the PostCSS step: building without the `autoprefixer` step gives a different `dark.css` (for example `appearance:menulist-button` loses its `-webkit-` / `-moz-` prefixes).
- **`npm run build:style`** (full script, run with a bash script shell): the built CSS matches the committed files. Its `lint:style-fix` step adds two blank lines to `base.less` both before and after the update; that change is not part of this PR.
- **`npm run lint:style`**: the same 223 problems before and after (the output is identical once colour codes are removed). `lint:style-fix` output and the changes it makes to the `.less` files are also identical.
- **Node 20.20.2** (the version used by the Playwright job): `npm ci` succeeds with an `EBADENGINE` warning for `postcss-cli`, and `lessc` + `postcss` on Node 20 builds a `dark.css` that is byte-identical to the committed file.
- `npm audit`: 15 findings (13 high, 2 moderate) before, 10 high after (only the `braces` path through `stylelint`).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
