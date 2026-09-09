## What happens

`Duplicati.CommandLine list-file-versions <url> "<path>"` and `POST /api/v2/backup/list-versions` answer with
nothing, whatever path is given. After one backup of a folder holding `a.txt` and `sub\b.txt`:

```
> Duplicati.CommandLine list-file-versions file://... "<src>\a.txt" "<src>\sub" "<src>\sub\b.txt" ...
File versions:
```

The same call through `Controller.ListFileVersionsAsync` returns `TotalCount = 0`, also for `"<src>\sub\"`,
`"a.txt"` and `"b.txt"`. This has been so since the operation was added (a3bc9b80, 2025-04-29).

### Why

Two halves that each guarantee an empty answer:

- `ListFileVersionsHandler` appends a directory separator to every path
  ([ListFileVersionsHandler.cs:68](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/ListFileVersionsHandler.cs#L68)),
  so a file is asked for as `a.txt\`. Files are stored without the separator.
- `LocalListDatabase.ListFileVersionsAsync` compares the paths with `FileLookup."Path"`
  ([LocalListDatabase.cs:1277](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Database/Local/LocalListDatabase.cs#L1277)),
  which holds only the part after the path prefix. The full path is `PathPrefix."Prefix" || FileLookup."Path"`
  ([Schema.sql:127](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Database/Local/Database%20schema/Schema.sql#L127),
  the `File` view), and that is what the neighbouring `ListFolderAsync` and `SearchEntriesAsync` use. The same
  column is returned as the path ([:1304](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Database/Local/LocalListDatabase.cs#L1304)),
  so even a match would have come back as a bare name.

A third defect in the same function shows as soon as the first two are fixed: the fileset timestamp is stored in
epoch seconds but read as ticks ([:1350](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Database/Local/LocalListDatabase.cs#L1350)),
so every version was dated `0001-01-01`.

The existing tests did not see any of this: `ListFileVersions_LifecycleTestAsync` asserts inside a loop over the
returned paths, so an empty answer passes, and `ListFileVersions_WithLargeFilesetIds_UsesTemporaryTableAsync` calls
the database with `"file.txt"` - the suffix column itself, not the value the handler passes.

## The change

- `ListFileVersionsAsync` joins `PathPrefix`, matches and returns `"pp"."Prefix" || "fl"."Path"`, orders by
  prefix, name, timestamp (a path's versions stay contiguous, which the CLI relies on), and narrows the scan with
  `"fl"."PrefixID" IN (...)` from the prefixes of the paths asked for (the leading column of `FileLookupPath`),
  the way `ListFolderAsync` does. The fileset time is read with `ParseFromEpochSeconds`, like `ListFilesetsAsync`.
- `ListFileVersionsHandler` passes each path as given and, when it has no trailing separator, the folder form as
  well, so a folder is found whether or not the caller added the separator.

After the change, the CLI call above:

```
File versions:
<src>\a.txt:
  [0] 2026/09/13 12:58:50: (4 bytes)
<src>\sub\:
  [0] 2026/09/13 12:58:50: (directory)
<src>\sub\b.txt:
  [0] 2026/09/13 12:58:50: (6 bytes)
```

with the time equal to what `list-filesets` prints for version 0.

## Red to green

`--filter "FullyQualifiedName~ListFileVersions"`:

| Test | Before |
|---|---|
| `ListFileVersions_LifecycleTestAsync` (now asserts one group per path asked for) | `Expected: 4 But was: 0` |
| `ListFileVersions_ReturnsFullPathsForFilesAndFoldersAsync` (new: file, folder with and without the separator, full path, `IsDirectory`, size, version time) | `Expected: equivalent to < ... > But was: <empty>` |
| `ListFileVersions_WithLargeFilesetIds_UsesTemporaryTableAsync` (now called with the full path `/test/file.txt`) | `Expected: 150 But was: 0` |

All three pass after the change, on Windows and on Linux (WSL). `DirectListHandlerTests` as a whole: 14 passed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
