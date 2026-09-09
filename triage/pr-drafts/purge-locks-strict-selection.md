## What happens

`purge` limited to a version or a time that matches no fileset purges from **every** fileset instead. With
versions 0 and 1 in the backup and `a.txt` in both:

```
> purge --version=5 --include=*/a.txt
  Warning: Skipping invalid version: 5
  RemovedFileCount=2 RewrittenFileLists=2
  version 0 now holds: b.txt
  version 1 now holds: b.txt
```

The help text says the default is all versions and that `--version` limits it; here the limit silently turns into
the default, with one warning line. `--time` earlier than the first backup does the same. `set-locks` takes its
filesets through the same lookup, so a version or a time that matches nothing locks the volumes of every
version, and reports it as "No version specified".

### Why

`GetFilelistWhereClauseAsync` drops a version that does not exist with a warning; when no version is left and
no time was given, it builds no condition at all, and every fileset matches
([LocalDatabase.cs:762-800](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/Library/Main/Database/Local/LocalDatabase.cs#L762-L800)).
A time that nothing is at or before matches nothing, and `GetFilesetIDsAsync` then falls back to every fileset
("selecting newest backup",
[:1543-1556](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/Library/Main/Database/Local/LocalDatabase.cs#L1543-L1556)).
Both are what a restore wants: it walks the filesets newest first and stops at the first one holding the
files. `PurgeFilesHandler`
([:78-84](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/Library/Main/Operation/PurgeFilesHandler.cs#L78-L84))
and `SetLocksHandler`
([:164-170](https://github.com/duplicati/duplicati/blob/343d00c4ce8209e732ee85c3a15a744fecb3f89a/Duplicati/Library/Main/Operation/SetLocksHandler.cs#L164-L170))
act on every fileset they are handed, so for them the fallback is the wrong answer. The purge handler's
"No filesets matched the supplied time or versions" was unreachable.

## The change

A new `LocalDatabase.GetSelectedFilesetIDsAsync(time, versions)` returns the filesets a selection points at and
nothing else: it reuses `GetFilelistWhereClauseAsync`, treats a selection made only of versions that do not
exist as a selection of nothing, and has no fallback. Without a time and without versions it still returns
every fileset, which is the documented purge default. `purge` and `set-locks` use it; the existing
`NoFilesetFoundForTimeOrVersion` check in purge now fires, and set-locks reports "No fileset matched the given
version or time" (same help id as before). `GetFilesetIDsAsync` and its callers - restore, list, search,
list-file-versions, test, list-broken-files - are unchanged.

## Red to green

`--filter "FullyQualifiedName~PurgeWithASelectionThatMatchesNothing|FullyQualifiedName~DoesNotLockAnythingForASelection"`:

| Test | Before |
|---|---|
| `PurgeTesting.PurgeWithASelectionThatMatchesNothingPurgesNothingAsync` (`--version=5` and `--time=<a day before the first backup>` must throw and leave both versions intact; `--version=1` purges only version 1) | no exception; the file was purged from both versions |
| `SetLocksHandlerTests.DoesNotLockAnythingForASelectionThatMatchesNothingAsync` (`--version=99` and a time before the only backup must lock nothing) | no exception; every volume was locked |

Both pass after the change, on Windows and on Linux (WSL). `TestCategory=Purge`, `TestCategory=LockHandler` and
`SetLocksHandlerTests` are green.

## Noted, not changed

The purge help describes `--time` as selecting "a specific version"; the implementation, like restore's, selects
every fileset at or before that time.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
