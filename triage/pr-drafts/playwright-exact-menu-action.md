Branch: `test/playwright-exact-menu-action` (from master 7cdde15855229eed3c2da0690a3848522aaff55b)
Title: Match the backup menu action by its exact name in the Playwright test
Merge order: independent of the other open branches (only touches `playwright-tests/backupRestore.spec.ts`).

## Summary

`backup and restore flow` starts by deleting a backup with the same name left over from an earlier run. It opens the backup's menu and picks the action with `.filter({ hasText: action })`, which matches by substring. The menu has both "Delete" and "Delete versions", so when the backup already exists the click fails:

```
Error: locator.click: Error: strict mode violation: locator('div.backup').filter({ hasText: 'PlaywrightBackup' }).locator('div.options button').filter({ hasText: 'Delete' }) resolved to 2 elements:
    1) <button ...>…</button> aka getByRole('button', { name: 'Delete', exact: true })
    2) <button ...>…</button> aka getByRole('button', { name: 'Delete versions' })
```

CI starts a new server for each run, so it never reaches this path; running the tests a second time against the same server (for example with `playwright-tests/run-tests-headed.sh`) always failed.

`clickThreeDotMenu` now picks the button by its exact accessible name (`getByRole("button", { name: action, exact: true })`). The other callers ("Restore", "Export") still work.

Commit: [6c866d4a152237247a8ab696bbbc6d9a630c97f6](https://github.com/JamBalaya56562/duplicati/commit/6c866d4a152237247a8ab696bbbc6d9a630c97f6)

## Testing

Server published from master and started like the CI job (`--disable-db-encryption --webservice-password=easy1234 --webservice-suppress-welcome-page`).

- Before (master): the second run of `backupRestore.spec.ts` against the same server fails with the strict mode violation above, on Node 20.20.2 and on Node 26.12.0.
- After: on a fresh server, run 1 (Node 20) passes and creates the backup; run 2 (Node 20) and run 3 (Node 26) against the same server delete the existing backup through the menu and pass. Each run also uses "Restore" and "Export" through the same helper.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
