## What happens

The root listing - `list-folder` with no folder, which is what the restore tree in the web UI asks for first -
leaves out a source whose path continues the name of another, file, source.

Backup with three sources, `notes.txt`, `notes.txt.old` and the folder `f1`, then ask for the roots
(`Controller.ListFolderAsync(null, 0, 0, false)`, or `POST /api/v2/backup/list-folder` with `Paths: null`):

```
<data>\f1\           (directory)
<data>\notes.txt
```

`notes.txt.old` is not there, so the restore tree cannot show it and it cannot be picked from the tree (search
still finds it). The same happens for `app.log` next to `app.log.1`, or a file `report` next to a folder
`report-2026`. Sources that are all folders are not affected: the trailing separator keeps them apart in the sort.

### Why

`LocalListDatabase.GetMinimalUniquePrefixEntriesAsync` sorts the fileset's paths and takes an entry as "below the
previous root" when its path starts with that root
([LocalListDatabase.cs:1183](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Database/Local/LocalListDatabase.cs#L1183)).
That is a plain string prefix test, so after the root `…\notes.txt` the entry `…\notes.txt.old` counts as a child.
A file has nothing below it; only a folder root - a path that ends with a directory separator - can.

The five existing `GetMinimalUniquePrefixEntries_*` tests seed folder roots only.

## The change

A root absorbs the entries after it only when it ends with a directory separator. One condition in
`GetMinimalUniquePrefixEntriesAsync`; the query, the returned entries and their order are unchanged. The
check is on the path's trailing separator rather than on the blockset id because that is what the path family
is keyed on in the sort, and it is what the seeded tests store.

## Red to green

`--filter "FullyQualifiedName~FileRootsDoNotAbsorb|FullyQualifiedName~RootsIncludeASource"`:

| Test | Before |
|---|---|
| `GetMinimalUniquePrefixEntries_FileRootsDoNotAbsorbLongerNamesAsync` (seeded: `f1/`, `notes.txt`, `notes.txt.old`, `report`, `report-2026/` and their contents) | `Missing (2): < "/data/notes.txt.old", "/data/report-2026/" >` |
| `ListFolder_RootsIncludeASourceThatExtendsAnotherSourcesNameAsync` (real backup of the three sources, roots through the controller) | `Missing (1): < "…\notes.txt.old" >` |

Both pass after the change, on Windows and on Linux (WSL). `DirectListHandlerTests` as a whole is green (15).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
