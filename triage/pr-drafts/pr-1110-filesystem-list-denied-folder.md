Expanding a Windows compatibility junction such as `%USERPROFILE%\Cookies` or `%USERPROFILE%\Anwendungsdaten` in the source picker fails with `{"Error":"An error occurred","Code":500}` (duplicati/ngclient#636). An ordinary junction, or the target of the compatibility junction, opens fine.

## Cause

The compatibility junctions in a Windows profile (`Cookies`, `Application Data`, `Local Settings`, ...) carry an `Everyone Deny ListDirectory` entry in their ACL. When `POST /api/v1/filesystem` lists one, `EnumerateFileSystemEntries` throws `UnauthorizedAccessException`. `Execute` wrapped it in a plain `Exception`, so the web server reported it as an unhandled exception with HTTP 500. From the server log:

```
System.Exception: Failed to process the path: Access to the path '\\?\C:\Users\Jam\Cookies' is denied.
 ---> System.UnauthorizedAccessException: Access to the path '\\?\C:\Users\Jam\Cookies' is denied.
   at System.IO.Enumeration.FileSystemEnumerator`1.CreateDirectoryHandle(String path, Boolean ignoreNotFound)
   ...
   at Duplicati.Library.Common.IO.SystemIOWindows.EnumerateFileSystemEntries(String path)
   at Duplicati.WebserverCore.Endpoints.V1.Filesystem.ListFolderAsNodes(String entrypath, Boolean skipFiles, Boolean showHidden)+MoveNext()
```

The listing of the parent folder already reports such a junction with `"kind":"locked"`, `"leaf":true` and `"iconCls":"x-tree-icon-locked"`.

## The change

- When the requested folder itself cannot be listed because access is denied, the endpoint returns 403 with a message that names the folder: `{"Error":"Access to the folder is denied: C:\\Users\\Jam\\Cookies\\","Code":403}`.
- Only the enumeration of the requested folder is covered. Other errors are reported as before.
- `Execute` now rethrows a `UserReportedHttpException` instead of wrapping it, so that the status code reaches the client.
- No ACL is changed, and no link is followed.

ngclient does not treat a 403 specially (only 401), so the message is shown as the error notification. The tree could also avoid requesting the children of a node whose `kind` is `locked`; that is for ngclient.

## Testing

New `ServerApiIntegrationTests.ListingAFolderThatMayNotBeListedIsForbidden_Async`. It creates a folder, denies listing it to the account that runs the test (`Deny ListDirectory` on Windows, mode `000` elsewhere, restored at the end), and lists it through the API. A folder next to it must still list.

| | before | after |
|---|---|---|
| the denied folder | **fail**: `{"Error":"An error occurred","Code":500}` | 403 with the folder in the message |
| the open folder | 200 | 200 |

`SourceProviderFilesystemPluginTests` also passes (3 tests in all). No new warnings in the changed files.

I also ran the server built from master and from this branch, with an isolated `--server-datafolder` on Windows 11, and sent the same requests:

| request | master | this branch |
|---|---|---|
| `%HOME%\Cookies\` and `C:\Users\<user>\Cookies\` | 500 | 403 |
| `%HOME%\Application Data\` | 500 | 403 |
| the target `...\AppData\Local\Microsoft\Windows\INetCookies\`, as an absolute path and below `%HOME%` | 200 | 200, the first 600 characters of the response are the same |
| a junction I created, and its target | 200 | 200, the first 600 characters of the response are the same |

I could not try the German `Anwendungsdaten` from the report, which points to `%APPDATA%` like `Application Data`.

Refs duplicati/ngclient#636

🤖 Generated with [Claude Code](https://claude.com/claude-code)
