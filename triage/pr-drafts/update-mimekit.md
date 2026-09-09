## Summary

`MimeKit` 4.17.0 (used by `Duplicati.Library.Modules.Builtin` and `Duplicati.Proprietary.Office365`) asks for `System.Security.Cryptography.Pkcs` 10.0.0, which is affected by [GHSA-846f-f764-76mx](https://github.com/advisories/GHSA-846f-f764-76mx) (high) and [GHSA-2fmv-rv2c-59x7](https://github.com/advisories/GHSA-2fmv-rv2c-59x7) (moderate), both fixed in 10.0.13.

#7478 moved `Duplicati.Library.SecretProvider` to Pkcs 10.0.13, so the executables already resolve and ship 10.0.13. The projects that only reach Pkcs through MimeKit (Backends, SourceProviders, Modules.Builtin, LoaderHelper, Office365) still resolve 10.0.0 and report `NU1902`/`NU1903`. They would also ship the vulnerable version if an executable stopped referencing SecretProvider.

This updates `MimeKit` to 4.18.2, which depends on Pkcs 10.0.13. `MailKit` stays at 4.17.0 (it needs `MimeKit` >= 4.17.0).

Commit: [43424b310570bcca598283431ed38f4490798b93](https://github.com/JamBalaya56562/duplicati/commit/43424b310570bcca598283431ed38f4490798b93)

## Testing

- `dotnet restore Duplicati.slnx`: the Pkcs `NU1902`/`NU1903` warnings are gone. Every project that uses Pkcs now resolves 10.0.13 (`dotnet list package --include-transitive`). The remaining audit warnings are for `MessagePack`, which is handled in a separate PR (StreamJsonRpc update).
- `dotnet build` of `Duplicati.Proprietary.Office365` and `Executables/Duplicati.CommandLine`: 0 errors, no compiler warnings.
- Sent a backup report through the send-mail module (MailKit 4.17.0 + MimeKit 4.18.2) to a local SMTP sink: `Duplicati.CommandLine.exe backup ... --send-mail-url=smtp://127.0.0.1:2525 --send-mail-level=all`. The message arrived with the expected `From`, `To` and `Subject: mimekit check Backup Success` headers and the result body. The `MimeKit.dll` in the output folder has the same SHA-256 as `lib/net10.0/MimeKit.dll` in the 4.18.2 package.
- Not tested: the Office365 restore path (`MimeMessage.LoadAsync`) beyond building.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
