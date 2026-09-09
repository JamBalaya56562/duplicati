Branch: `docs/server-readme-style-build` (on top of `ci/check-ngax-css-build` 25b7da504d73e82a2bab37093b199172f4806654)
Title: Point the server README to the npm scripts for the ngax styles
When to open: after `ci/check-ngax-css-build` is merged. Rebase onto master first (`jj rebase -s docs/server-readme-style-build -d master@upstream`); the branch then has only the README commit. It needs the `build:style:css` script that `ci/check-ngax-css-build` adds.

## Summary

`Duplicati/Server/README.md` told contributors to build the ngax styles with `npx lessc` only. `build:style` also runs Autoprefixer through PostCSS, so CSS built from the README differs from the committed `dark.css` / `default.css` (it has different vendor prefixes), and the new CSS check fails on it. The lint command in the README (`npx stylelint "**/less/*.less"` from `Duplicati/Server`) also picked up the copies in `bin` after a build.

The README now points to `npm run lint:style` and `npm run build:style:css`, says what `build:style:css` does and that a CI check compares the built files with the committed ones, and mentions `lint:style-fix` and `build:style`. It also lists Autoprefixer / PostCSS among the tools.

Commit: [32709405bfe164dc57211cb7244516e91cc33660](https://github.com/JamBalaya56562/duplicati/commit/32709405bfe164dc57211cb7244516e91cc33660)

## Testing

Run from `Duplicati/Server`, as the README says, after `npm ci` in the repository root:

- The old README commands (`npx lessc` for `dark.less` and `default.less`) change both committed CSS files (`2 files changed, 4 insertions(+), 4 deletions(-)`).
- `npm run build:style:css` (npm finds the root `package.json` from the subfolder) leaves both files unchanged.
- `npm run lint:style` also runs from the subfolder.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
