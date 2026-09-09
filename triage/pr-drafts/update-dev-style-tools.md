## Summary

The root `package.json` only holds the tools used to build and lint the ngax styles (`build:style`, `lint:style`) and Playwright. On master, `npm audit` reports 3 findings (1 high, 2 moderate):

- `nanoid` < 3.3.18 ([GHSA-2v37-7h3g-55p8](https://github.com/advisories/GHSA-2v37-7h3g-55p8)), via `postcss`
- `colord` < 2.9.4 ([GHSA-2wm5-q62r-hmrv](https://github.com/advisories/GHSA-2wm5-q62r-hmrv)), via `stylelint`
- `yaml` 2.0.0 - 2.8.2 ([GHSA-48c2-rrv3-qjmp](https://github.com/advisories/GHSA-48c2-rrv3-qjmp)), via `postcss-cli` → `postcss-load-config`

This PR:

- runs `npm audit fix` (no major updates): `nanoid` 3.3.16 → 3.3.20, `colord` 2.9.3 → 2.10.0.
- updates `postcss-cli` from `^11.0.0` to `^12.0.0`. `postcss-load-config` 6 no longer installs `yaml`, and `postcss-cli` 12 uses `chokidar` 5 and `tinyglobby` instead of `chokidar` 3.

`@playwright/test` and its dependencies are unchanged. No other files change. After the update, `npm audit` reports no vulnerabilities.

`postcss-cli` 12 declares `engines.node >= 22`; the Playwright job runs on Node 26.

#7836 also changes `package.json` (the `build:style` scripts, not the dependencies). The two merge together without a conflict.

## Testing

- On the current master with this change, on Windows with Node 26.13.1: `npm ci`, then the `lessc` + `postcss` steps of `build:style`. The built `ngax/styles/dark.css` and `default.css` are byte-identical to the committed files (same SHA-256).
- `npm audit`: 3 findings (1 high, 2 moderate) on master, none with this change.
- Earlier, with Node 24.21.0 and the lockfiles before and after the update: the built CSS was byte-identical, building without the `autoprefixer` step gave a different `dark.css` (so the comparison catches a change in the PostCSS step), and `npm run lint:style` gave the same 223 problems.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
