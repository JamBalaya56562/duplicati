## What happens

`Duplicati.CommandLine list-folder-contents <url> [folder]` without `--version` or `--time` fails as soon as
the backup has two filesets:

```
Multiple filesets found, please specify a single version or time
```

The command's help says otherwise ([help.txt:158](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/CommandLine/CLI/help.txt#L158)):
"If no fileset is specified, the latest fileset is picked." `POST /api/v2/backup/list-folder` without `Time`
behaves the same way. The web UI always sends a time, so it is not affected.

### Why

`ListFolderHandler` asks for the filesets matching `options.Time` and `options.Version`
([ListFolderHandler.cs:53-61](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/Library/Main/Operation/ListFolderHandler.cs#L53-L61))
and rejects more than one. Without `--time` the time is `DateTime(0)` and without `--version` the versions are
`null`, and for that combination `GetFilelistWhereClauseAsync` builds no condition at all
([LocalDatabase.cs:762](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/Library/Main/Database/Local/LocalDatabase.cs#L762)),
so every fileset matches. The existing `ListFolderContentsAsync` test passes a version on every call.

## The change

When neither a time nor a version is given, `ListFolderHandler` selects version 0, the newest fileset. An
explicit time or version is passed through unchanged, and so are the `NoFilesetsFound` and
`MultipleFilesetsFound` checks. `search` and `list-file-versions` are left alone: for them "all versions" is
the documented default.

## Red to green

`--filter "FullyQualifiedName~NoTimeOrVersion"`:

| Test | Before |
|---|---|
| `ListFolder_NoTimeOrVersion_ListsTheLatestFilesetAsync` (two backups; no version lists the folder and the roots of the latest, `--version=1` still lists the older one) | `UserInformationException : Multiple filesets found, please specify a single version or time` |

Passes after the change, on Windows and on Linux (WSL). `DirectListHandlerTests` as a whole is green.

## Noted, not changed

The `search` help says under `--version` that the latest backup is used when none is given, and under
`--all-versions` that searching all backup sets is the default. The implementation does the latter.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
