## Summary

With `--store-task-config` set on a job, a restore warns that the option is not supported and will be ignored ([forum topic 22816](https://forum.duplicati.com/t/22816), 2.4.0.1).

The option is read by the server: before a backup runs, `Runner` stores the task configuration in the backup and removes the option from the options it passes on. That happens only for backups, so every other operation run through `Runner` got the option, and the library warned about it (`UnsupportedOption`). On master, restore, verify and compact each end with this warning.

This removes the option for the other operations too ([548ea03](https://github.com/JamBalaya56562/duplicati/commit/548ea0312663fd7dab8a782c17fe5c62a9971e2d)). Backups are unchanged. `store-task-config` is the only option in `DuplicatiWebserver.ServerOnlyOptions`; the server-only `oauth-url` is one of the library's own options and does not warn.

## Testing

- `ServerApiIntegrationTests.StoreTaskConfigIsNotPassedToOtherOperations_Async` creates a job with `store-task-config=Self` on a test server, runs a backup, a restore, a verify and a compact, and expects no notification about the option after each. It then restores the stored task configuration and expects one job back, so the backup still stores it. On master it fails at the restore (`[Warning-Duplicati.Library.Main.Controller-UnsupportedOption]: ... --store-task-config ...`). It passes with this change.
- `StoreTaskConfigModeTests` still pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
