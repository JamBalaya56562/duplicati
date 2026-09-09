`POST /api/v1/filesystem` used `resolvedpath` for two different things:

- When a folder is listed by its path, `resolvedpath` was the **target** of a symlink or junction, and null for any other entry.
- Below a special folder such as `%HOME%`, `id` is the shortened path (`%HOME%\Cookies\`) and `resolvedpath` is the **path of the entry** (`C:\Users\<user>\Cookies\`), for every entry. The target of a link was overwritten there, so it was lost.

ngclient treats `resolvedpath` as the full path of the node: the picked value with `resolvePaths`, `currentPathResolved` and the filter checks. From the ngclient code (`#resolveNodeId` returns `resolvedpath` when it is set), picking a link in a folder listed by its path gave its target, and picking the same link below `%HOME%` gave the link itself. I have not tried this in the UI.

## The change

- `resolvedpath` keeps one meaning: the full path of the entry below a special folder. A listing by path leaves it null, as it already did for entries that are not links.
- The target of a link is reported in a new `symlinkTarget` field, in both listings. It is null when the entry is not a link.

Picking a link in a folder listed by its path now gives the link, as it does below `%HOME%`. The old UI does not read `resolvedpath`. ngclient does not show the target yet; it could use `symlinkTarget` for that.

## Testing

Two new tests in `ServerApiIntegrationTests`:

| test | master | this branch |
|---|---|---|
| `AListedLinkReportsItsTargetSeparately_Async`: lists a folder with a link (a junction on Windows, a symbolic link elsewhere) by its path | **fail**: `symlinkTarget` is missing (the target is in `resolvedpath`) | pass: `resolvedpath` is null, `symlinkTarget` is the target |
| `ALinkBelowTheHomeFolderKeepsItsOwnResolvedPath_Async`: lists `%HOME%\` and checks every link in it (only reads the home folder; ignored when it holds no link) | **fail**: "The target of Application Data must be reported" | pass |

`SourceProviderFilesystemPluginTests` also passes (4 tests in all). No new warnings in the changed files.

I also compared the API of a server built from master and from this branch, with an isolated `--server-datafolder` on Windows 11:

| listing | link | master | this branch |
|---|---|---|---|
| `%HOME%\` | `Cookies` (and the 9 other compatibility junctions) | `resolvedpath` = `C:\Users\<user>\Cookies\`, no target | the same `resolvedpath`, `symlinkTarget` = `C:\Users\<user>\AppData\Local\Microsoft\Windows\INetCookies` |
| `C:\Users\<user>\` | `Cookies` | `resolvedpath` = the target | `resolvedpath` null, `symlinkTarget` = the target |
| a folder with a junction I created | `link` | `resolvedpath` = the target | `resolvedpath` null, `symlinkTarget` = the target |

Checked together with #7772 and #7776 in one temporary merge: no conflict, it builds, and the tests of all three pass (53 tests).

Found while looking into duplicati/ngclient#636.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
