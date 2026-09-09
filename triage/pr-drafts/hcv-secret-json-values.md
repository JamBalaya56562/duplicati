Fixes #7412

## What happens

Since [`819af9e66f8fd3534d863a3cde05531777f09edd`](https://github.com/duplicati/duplicati/commit/819af9e66f8fd3534d863a3cde05531777f09edd) (in 2.2.1.0 beta and 2.3.0.0 stable), VaultSharp is 1.17.5.1 instead of 1.7.0. The new version reads the secret data with System.Text.Json, so each value in `Data.Data` is a `JsonElement`, not a `string`. `HCVaultSecretProvider.ResolveSecretsAsync` kept only the values that were strings, so it found none, and failed with "The following keys were not found" for keys that were there. This is the crash in the issue.

## The change

The three places that checked `is string` now read the value through a small helper that accepts a `string` or a `JsonElement` holding a string.

## Checked

`HCVaultSecretProviderResolveTests` (new) answers the provider from a local listener with KV v2 responses, for the three ways a key is found: in a listed secret, under its own path, and as the only value under its own path. All three failed with `KeyNotFoundException` before the change and pass after it.

Against a real Vault (`hashicorp/vault:1.17` in dev mode, a secret `duplicati` holding `ENCRYPTION_KEY`), `Duplicati.CommandLine.SecretTool test` with the URL form from the issue:

| | Result |
|---|---|
| Before | `KeyNotFoundException: The following keys were not found: ENCRYPTION_KEY` |
| After | `ENCRYPTION_KEY: Found!` |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
