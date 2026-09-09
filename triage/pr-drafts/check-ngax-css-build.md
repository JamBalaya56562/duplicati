Branch: `ci/check-ngax-css-build` (from master 7cdde15855229eed3c2da0690a3848522aaff55b)
Title: Check in CI that the committed ngax CSS matches the .less files
Merge order: independent of `chore/update-dev-style-tools`. Both touch `package.json` (different lines); merging the two together has no conflict, and the combined tree passes the new check on Node 20.

## Summary

The ngax styles are committed twice: as `.less` sources and as the built `ngax/styles/dark.css` and `default.css`. Nothing checks that the two agree, so a `.less` change without a rebuild, a hand edit of the CSS, or a dependency update that changes the output (for example `autoprefixer`) would go unnoticed.

This adds a `ngax styles` workflow that runs on pull requests touching the `.less` files, the built CSS, `package.json`, `package-lock.json` or the workflow itself (and on `workflow_dispatch`). It runs `npm ci`, rebuilds the CSS, and fails if the result differs from the committed files. The CSS is minified, so on failure it prints the difference with one rule per line.

`build:style` first runs `lint:style-fix`, which edits the `.less` files (today it adds two blank lines to `base.less`). The `lessc` + `postcss` part moves to a new `build:style:css` script, which the workflow runs; `build:style` now runs `lint:style-fix` and then `build:style:css`, the same commands as before.

The job uses Node 20 like the Playwright job. Note: if `postcss-cli` 12 is merged (separate PR), it declares `engines.node >= 22`; on Node 20 `npm ci` prints an `EBADENGINE` warning and the check still passes (tested, see below).

Commit: [25b7da504d73e82a2bab37093b199172f4806654](https://github.com/JamBalaya56562/duplicati/commit/25b7da504d73e82a2bab37093b199172f4806654)

## Testing

Ran the workflow's own `run:` steps (extracted from the YAML) with `bash --noprofile --norc -eo pipefail` in a `node:20` container (Node 20.20.2, npm 10.8.2), on a git checkout of the changed tree:

- Unchanged tree: `The built CSS matches the committed files.`, exit 0.
- `margin-top: 10px` → `11px` in one place in `base.less`, CSS not rebuilt: fails, and the output shows the changed rule for both files:
  ```
  -.exportpage .checkbox input{width:auto;margin-top:10px
  +.exportpage .checkbox input{width:auto;margin-top:11px
  ```
- `--use autoprefixer` removed from `build:style:css`: fails, the output shows the prefix differences (for example `-webkit-appearance` / `-moz-appearance` on `form.styled .input.select select`).
- A space appended to the committed `default.css`: fails.
- The tree with `chore/update-dev-style-tools` merged in (postcss-cli 12): passes on Node 20 (with the `EBADENGINE` warning from `npm ci`).
- `actionlint` 1.7.12 (with shellcheck 0.11.0) reports nothing for the new workflow.
- Not tested: the Plumber score. The workflow only uses `actions/checkout@v7` and `actions/setup-node@v6` like `tests.yml`, and sets read-only permissions and a timeout.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
