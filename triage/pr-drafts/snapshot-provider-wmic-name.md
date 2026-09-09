# Keep accepting Wmic as the name of the WMI snapshot provider

203694caa ("Switch to VMI") replaced the WMIC snapshot provider with a WMI one and renamed the value from `Wmic` to `Wmi`. The 2.4 stable releases still call it `Wmic`, and jobs saved with `--snapshot-provider=Wmic` keep that value after an update.

On master such a job:

- gets a warning on every run, so it ends with warnings:
  ```
  [Warning-Duplicati.Library.Main.Controller-OptionValidationError]: The option --snapshot-provider does not support the value "Wmic", supported values are: AlphaVSS, Wmi, Vanara, Native
  ```
- silently uses the default provider, Native, instead of WMI. Native flushes the VSS writers, which the user had chosen not to do.

`Options` now reads `Wmic` (in any case) as `Wmi`, and writes it back to the raw options. The validation, `Options.SnapShotProvider` and the snapshot itself (made from `RawOptions`, as are the Hyper-V and MSSQL checks) all see `Wmi`. The old name is not listed in the help.

The changelog of 2.4.0.100 says the WMI provider "works similar to WMIC", so mapping the old name to it keeps what the user chose.

I could not find an issue for this. #7317 and #7005 are from users of `--snapshot-provider=Wmic`.

## Testing

New `SnapshotProviderOldNameTests` (Windows only):

- `TheOldWmicNameSelectsTheWmiProvider("Wmic")` and `("wmic")`: on master `Expected: Wmi But was: Native`; passes with the change.
- `ABackupWithTheOldWmicNameHasNoWarningAsync`: a backup with `--snapshot-policy=off --snapshot-provider=Wmic`. On master it ends with the `OptionValidationError` warning above; passes with the change.

`OptionsTests`, `SourceProviderOptionValidationTests`, `TestHyperVSourceProvider`, `TestMSSQLSourceProvider`, `SourceProviderFactorySnapshotOwnershipTests` and the new tests: 94 passed on Windows. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
