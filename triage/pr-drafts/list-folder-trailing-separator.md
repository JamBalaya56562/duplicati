## What happens

`Duplicati.CommandLine list-folder-contents <url> "<folder>"` answers with an empty listing when the folder is
given without a trailing directory separator - which is how it gets typed, since on Windows a trailing backslash
inside the quotes swallows the closing quote. The same goes for `POST /api/v2/backup/list-folder` with such a
path in `Paths`. After a backup holding `f1\a.txt`:

```
Paths = ["<data>\f1"]    ->  (nothing)
Paths = ["<data>\f1\"]   ->  <data>\f1\a.txt
```

The web UI is not affected: it passes the paths it got from a previous listing, which carry the separator.

### Why

`ListFolderHandler` hands the folders straight to `GetPrefixIdsAsync`
([ListFolderHandler.cs:76](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/ListFolderHandler.cs#L76)),
which matches `PathPrefix."Prefix"` exactly. A prefix is stored with its trailing separator (`SplitIntoPrefixAndName`
keeps it), so the bare folder name matches none. The neighbouring `SearchEntriesHandler` adds the separator with
`Util.AppendDirSeparator`; this handler was the one that did not.

## The change

`ListFolderHandler` appends the directory separator to each folder before the prefix lookup, the way
`SearchEntriesHandler` does. The "no folder given" branch is untouched, so an empty path still lists the roots.

## Red to green

`--filter "FullyQualifiedName~FolderWithoutTrailingSeparator"`:

| Test | Before |
|---|---|
| `ListFolder_FolderWithoutTrailingSeparator_ListsItsEntriesAsync` (folder with a file and a sub-folder, listed with and without the separator) | `Expected: equivalent to < "…\f1\a.txt", "…\f1\sub\" > But was: <empty>` |

Passes after the change, on Windows and on Linux (WSL). `DirectListHandlerTests` as a whole is green (14).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
