Title: Use --webservice-webroot inside the installation folder in release builds

## Summary

In release builds, `--webservice-webroot` was always ignored, and the server used the default webroot. The check compared the given folder with `getEntryAssembly().Location`. That is the path of the dll file, not of a folder, so no real folder could pass. Only a path below the dll file name passed, for example `...\Duplicati.Server.dll\customroot`, and the server then failed to start because that folder cannot exist.

The check was added in [d672be7f886772b37e9665d4ed6d305227977205](https://github.com/duplicati/duplicati/commit/d672be7f886772b37e9665d4ed6d305227977205) (2012). Its comment says it only allows folders in the same folders as the running application, "to avoid users that inadvertently expose top level folders". At that time it also accepted folders below the startup folder (`Program.StartupPath`, later `UpdaterManager.InstalledBaseDir`). [76983002e6dcfa52d31025830d26b775da4cead4](https://github.com/duplicati/duplicati/commit/76983002e6dcfa52d31025830d26b775da4cead4) ("Fixed a release build issue after removing autoupdater", 2024) removed that branch, and only the comparison with the dll path was left.

This change keeps the intent and compares with the installation folder again (`UpdaterManager.INSTALLATIONDIR`, which is the folder of the entry assembly). The check is now the method `WebServerLoader.IsWebrootBelowFolder`:

- Both paths are resolved with `Path.GetFullPath`, so `..` cannot leave the installation folder.
- Both paths end with a separator before the comparison, so `C:\app2` is not taken as inside `C:\app`.
- The installation folder itself is not accepted, only folders below it.
- Case is compared with `ClientFilenameStringComparison`, as before.
- Symbolic links are not resolved, as before.

When the option is ignored, a warning is now written to the log.

Debug builds are not changed.

Commit: [0ab93a20e403933d24c451e963d8817dac9a9edc](https://github.com/JamBalaya56562/duplicati/commit/0ab93a20e403933d24c451e963d8817dac9a9edc)

## Testing

- New `WebServerLoaderWebrootFolderTests` (7 tests) for `IsWebrootBelowFolder`: folders inside the installation folder are allowed, and the installation folder itself, folders outside it, `..` paths that leave it, a sibling folder with the same prefix, and empty or invalid values are rejected.
  - With the old comparison in the method, `FolderInsideInstallationFolderIsAllowed` and `CaseIsComparedWithTheGivenComparison` fail, and 5 tests pass.
  - With the change, 7 tests pass.
- I ran the release build of `Duplicati.Server.dll` with `--webservice-port=8398` and `marker.txt` files in test folders:

  | `--webservice-webroot` | `GET /marker.txt` | `GET /ngax/index.html` | Warning in log |
  |---|---|---|---|
  | `<install>\customroot` | 200 (`inside`) | 404 | none |
  | a folder outside the installation folder | 404 | 200 | `WebrootOutsideInstallation` |
  | `<install>\customroot\..\..\…\<outside folder>` | 404 | 200 | `WebrootOutsideInstallation` |
  | `<install>2\customroot` | 404 | 200 | `WebrootOutsideInstallation` |

  Before the change, `<install>\customroot` gave 404 for `/marker.txt` and 200 for `/ngax/index.html`.
- The debug and release builds have no new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
