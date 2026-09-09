Branch: `chore/ignore-playwright-output` (from master 7cdde15855229eed3c2da0690a3848522aaff55b)
Title: Ignore the files the Playwright tests leave in the repository
Merge order: independent (only `.gitignore`).

## Summary

Running the Playwright tests locally (`npx playwright test`, or `playwright-tests/run-tests-headed.sh`) leaves these in the repository root, and they showed up as new files:

- `test-results/` (the `outputDir` in `playwright.config.ts`: screenshots, traces, `.last-run.json`)
- `playwright-report/` (the HTML reporter, used in CI and with `--reporter=html`)
- `playwright_source/`, `playwright_destination/`, `playwright_restore/`, `playwright_temp/` (the folders `backupRestore.spec.ts` creates with `path.resolve`)

They are now in `.gitignore`, anchored to the root.

Commit: [c8fe991089ca6ec2b54689e776c3a4dc1bb52b82](https://github.com/JamBalaya56562/duplicati/commit/c8fe991089ca6ec2b54689e776c3a4dc1bb52b82)

## Testing

- Ran the whole Playwright suite with `--reporter=list,html` against a local server: all six folders were created (10 files), and `git status` / `jj status` show only the `.gitignore` change.
- `git check-ignore -v --no-index` on a path in each folder: with the master `.gitignore` none is ignored (exit 1); with this branch each one matches the new line for its folder.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
