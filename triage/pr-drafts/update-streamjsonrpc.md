## Summary

`StreamJsonRpc` 2.25.29 (used by `Duplicati.Library.Main` and `Duplicati.CommandLine`) brings in `MessagePack` 2.5.302, which is affected by [GHSA-qhrr-8q5h-9q3h](https://github.com/advisories/GHSA-qhrr-8q5h-9q3h) (fixed in 2.5.303). The build reports it as `NU1902` in 30 projects, and the vulnerable `MessagePack.dll` ships with the executables (`RecoveryTool` and `Server` both resolve 2.5.302).

This updates `StreamJsonRpc` to 2.26.150, which depends on `MessagePack` 2.5.307. Duplicati uses `SystemTextJsonFormatter` for its RPC, so MessagePack is not on the RPC path, but the package is still loaded with the executables.

Other packages that move with it: `Nerdbank.MessagePack` 1.2.4 → 1.3.88 and `Microsoft.VisualStudio.Threading.Only` 17.14.15 → 18.7.23. All projects resolve the same version of each, so the ReleaseBuilder duplicate-version check does not need new entries.

Commit: [2c074f5c2d7ca3d5ece0dfb32cb4921636702d22](https://github.com/JamBalaya56562/duplicati/commit/2c074f5c2d7ca3d5ece0dfb32cb4921636702d22)

## Testing

- `dotnet restore Duplicati.slnx`: the `MessagePack` `NU1902` warnings are gone. All 30 projects resolve `MessagePack` 2.5.307. The remaining audit warnings are for `System.Security.Cryptography.Pkcs`, which is handled in a separate PR (MimeKit update).
- `dotnet build Duplicati/UnitTest/Duplicati.UnitTest.csproj --no-incremental`: 0 errors, no compiler warnings (only the Pkcs audit warnings above).
- `dotnet test --filter "FullyQualifiedName~IPCTests"`: `RunBackupViaIPC_ReceivesCallbacksAsync` passed (it ran against the built controller executable, it was not ignored).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
