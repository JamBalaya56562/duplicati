## Summary

A backup with a passphrase and no `encryption-module` setting is encrypted by the server with the default module, `aes` (`Options.EncryptionModule` in Duplicati falls back to `aes` when the setting is empty). Such backups come from the API or from older clients.

The editor read the missing module as no encryption choice. `mapBackupToGeneralForm` left `encryption` undefined, `patchValue` kept the form default `''`, and `mapBackupFormToSettings` then saved the backup unchanged as:

```
--no-encryption=True
```

without the passphrase. The next run failed:

```
You have attempted to remove the passphrase on an existing backup, which is not supported.
```

`resolveBackupEncryptionSettings` now reads a backup that does not disable encryption and has a passphrase with the default module. Saving it unchanged keeps `encryption-module=aes` and the passphrase. A backup with `--no-encryption`, or without a passphrase, is read as before.

## Testing

- `ng test ngclient --include '**/backup-form-mappers.spec.ts' --include '**/backup-encryption-settings.spec.ts'`: 21 tests passed. The new mapper tests go through the editor's path: `createGeneralForm()`, `patchValue(mapBackupToGeneralForm(...))`, then `mapBackupFormToSettings(...)`. On `main` the two new ones fail with `expected undefined to be 'aes'` and `expected [ { Name: '--no-encryption', … } ] to deep equally contain { Name: 'encryption-module', … }`.
- The other 7 spec files that cover encryption in the backup editor, import and export: 122 tests passed.
- Prettier check passed on the changed files.
- With a local Duplicati server (current `master`) serving a development build of this branch: a backup created through the API with only a passphrase ran once, was opened in the editor and saved unchanged. The editor showed "Encrypted backup", the PUT carried `encryption-module=aes` and the masked passphrase, and the next run succeeded. The same steps with the current bundle (0.0.248) sent `--no-encryption=True` and the next run failed as above.

A server side change for the same kind of backup is in duplicati/duplicati: `--store-task-config=Auto` also took it as not encrypted (`fix/task-config-default-encryption-module`, not opened as a PR yet). This PR does not depend on it.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
