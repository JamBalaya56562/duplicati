Title: Use --webservice-webroot in debug builds

## Summary

In debug builds, `WebServerLoader.TryRunServerAsync` read `--webservice-webroot` but never assigned it. The comment there says "In debug mode we do not care where the path points", but the server always served the webroot found next to the source tree. That made it hard to run a debug server against another checkout or a changed copy of the web UI. The given folder is now used when it is not empty.

Release builds are not changed.

Commit: [48cd2cdb861a8ebfa5106bd75a342a44470013c6](https://github.com/JamBalaya56562/duplicati/commit/48cd2cdb861a8ebfa5106bd75a342a44470013c6)

## Testing

- New `WebServerLoaderWebrootTests.WebrootOptionIsUsedInDebugBuilds` calls `TryRunServerAsync` with `--webservice-webroot` pointing to a temporary folder. It passes a callback in place of the server, and checks the `WebRoot` the callback receives. It is ignored in release builds.
  - On master it fails: the `WebRoot` is `...\Duplicati\Server\webroot`, not the given folder.
  - With the change it passes.
- `WebServerLoaderWebrootTests` and `EncryptedFieldsWarningTests`: 4 passed, 0 failed.
- The build has no new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
