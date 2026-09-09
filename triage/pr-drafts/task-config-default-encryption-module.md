Title: Store the task config of a backup that uses the default encryption module

A job that is created through the API or by an older client can have a passphrase but no `encryption-module`. Its backup is encrypted with the default module (AES, `Options.EncryptionModule`), but with `--store-task-config` set to auto its task config was not stored: `Runner.IsBackupEncryptionEnabled` treated an empty `encryption-module` as no encryption. "Import from destination" then found no configuration for such a backup.

## The change

`IsBackupEncryptionEnabled` no longer requires `encryption-module` to be set. It still requires a passphrase.

## Testing

- New integration test `StoreTaskConfigAutoStoresTheConfigWhenTheDefaultEncryptionModuleIsUsed_Async` in `ServerApiIntegrationTests`: a job with only a passphrase makes `.aes` files. Before the change, `restore-task-config` returned `[]`; now it returns the config. All 35 `StoreTaskConfig` tests pass.
- With a server built with this change, running such a job writes `task-setup.json` into the dlist, and "Import from destination" in the web UI (ngclient 0.0.248) finds the job. Before, it said "No backup configurations found".

🤖 Generated with [Claude Code](https://claude.com/claude-code)
