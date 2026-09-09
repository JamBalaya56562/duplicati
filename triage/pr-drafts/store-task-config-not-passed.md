Title: Test that store-task-config is not passed to other operations

## Summary

#7556 removes `--store-task-config` from the options of every operation the server runs, so a restore of a job with the option no longer warns that it is not supported ([forum topic 22816](https://forum.duplicati.com/t/22816), 2.4.0.1).

This adds an integration test for that ([07ebd556](https://github.com/JamBalaya56562/duplicati/commit/07ebd556b997d12fe2b5d496855b953ee07b3a98)), so the warning does not come back. No code changes.

## Testing

`ServerApiIntegrationTests.StoreTaskConfigIsNotPassedToOtherOperations_Async` creates a job with `store-task-config=Self` on a test server. It runs a backup, a restore, a verify and a compact, and after each expects no notification about the option. It then restores the stored task configuration and expects one job back, so the backup still stores it.

- On master before #7556 (d8fade65), it fails at the restore: `[Warning-Duplicati.Library.Main.Controller-UnsupportedOption]: ... --store-task-config ...`.
- On current master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
