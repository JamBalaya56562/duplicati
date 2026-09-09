## What happens

`Duplicati.CommandLine search <url> "<folder>" --include=...` and `POST /api/v2/backup/search` with `Paths` search
only the entries directly in the folder. The help text promises more: "If folders are supplied, only those folders
and subfolders are searched." After a backup holding `c.txt`, `f1\a.txt` and `f1\sub\b.txt`, searching for `*.txt`:

```
Paths = null          ->  c.txt, f1\a.txt, f1\sub\b.txt
Paths = ["<data>\f1"] ->  f1\a.txt                         (f1\sub\b.txt is missing)
```

The web UI is not affected: it searches with `Paths: null`.

### Why

`LocalListDatabase.SearchEntriesAsync` restricts the folders with `"pp"."Prefix" IN (@PathPrefixes)`
([LocalListDatabase.cs:1604](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Database/Local/LocalListDatabase.cs#L1604)):
an exact match on the stored prefix, which is the entry's own parent folder. An entry in `f1\sub\` has the prefix
`…\f1\sub\`, not `…\f1\`, so it is never in the set.

The existing `SearchFilesTestAsync` scopes a search to `folder1`, but that folder has no sub-folder in the test, so
"direct children only" gives the expected count.

## The change

Each folder becomes a range on the prefix instead of an exact value: everything at or below `…\f1\` sorts in
`[…\f1\, …\f1])` (`[…/f1/, …/f10)` on Linux), and nothing beside it does - `…\f10\` sorts before `…\f1\`. The range
uses the index on `PathPrefix."Prefix"`, the same shape as the folder listing in #7316. The bounds travel in the
parameter set the filter already uses, so the fetch and count queries both see them; the temporary value list
for the prefixes is gone. Results, order and the "no folder" case are unchanged.

## Red to green

`--filter "FullyQualifiedName~FolderScopeIncludesSubfolders"`:

| Test | Before |
|---|---|
| `SearchEntries_FolderScopeIncludesSubfoldersAsync` (`c.txt`, `f1\a.txt`, `f1\sub\b.txt`, `f10\d.txt`; scope `f1` must give exactly `a.txt` and `sub\b.txt`, scope `f1\sub` exactly `b.txt`, no scope all four) | `Missing (1): < "…\f1\sub\b.txt" >` |

Passes after the change, on Windows and on Linux (WSL). `DirectListHandlerTests` as a whole is green (14).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
