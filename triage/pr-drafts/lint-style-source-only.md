Branch: `chore/lint-style-source-only` (from master 7cdde15855229eed3c2da0690a3848522aaff55b)
Title: Lint only the .less sources, not the copies in bin
Merge order: no conflict with `chore/update-dev-style-tools` or `ci/node-26`. It conflicts with `ci/check-ngax-css-build`, because the two change neighbouring lines in `package.json` (`build:style` there, `lint:style` / `lint:style-fix` here). Whichever merges second needs a rebase; the resolution is to keep both changes (the new `build:style` / `build:style:css` lines from that branch and the new lint pattern from this one).

## Summary

`lint:style` and `lint:style-fix` run stylelint on `Duplicati/Server/**/less/*.less`. A build copies the web root to `Duplicati/Server/bin/<configuration>/<framework>/webroot`, so after any build the pattern also matches `Duplicati/Server/bin/.../webroot/ngax/less/*.less`. `lint:style` then reports every problem twice, and `lint:style-fix` (which `build:style` runs first) also edits the build output.

The pattern is now `Duplicati/Server/webroot/**/less/*.less`, which matches the same source files (`ngax/less/*.less`) and nothing under `bin`.

Commit: [292ebd9ef9d18ccc0ffc9bd5099ff8a65e373e07](https://github.com/JamBalaya56562/duplicati/commit/292ebd9ef9d18ccc0ffc9bd5099ff8a65e373e07)

## Testing

With a copy of `webroot/ngax/less` in `Duplicati/Server/bin/Debug/net10.0/webroot/ngax/less` (where `dotnet publish` of the server puts it):

- Before (old pattern): `✖ 446 problems`, reported for `base.less`, `dark.less` and `form.less` both under `webroot` and under `bin`.
- After (`npm run lint:style`): `✖ 223 problems`, only for the files under `webroot`. This is the same output as the old pattern gives on a tree without a build.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
