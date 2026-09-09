Part of #6461. This fixes the first of the places where "Stop now" left a backup running for ever on a source that stopped answering: listing the source.

## What happens

Listing a folder and reading the attributes of an entry are synchronous calls that do not look at the cancellation token. On a source that stopped answering, as a network share can, one of them gets stuck, and the listing does not end when the backup is stopped.

The listing runs twice: once for the backup, and once to count the files for the progress bar (`CountFilesHandler`). The backup waits for both, so "Stop now" never made it return.

Measured on Linux against a small FUSE file system that stops answering one kind of request:

| The file system stops answering | Before | After |
|---|---|---|
| `getattr` | still running 30 s after the abort | returned 0.16 to 0.17 s after the abort, with the cancellation |
| `listxattr` | still running 30 s after the abort | the same |
| `readdir` | still running 30 s after the abort | the same |

## The change

`FileEnumerationProcess.RunAsync` runs the listing on its own task, and stops waiting for it when the operation is aborted, or when the caller no longer wants the listing (the token the file counter is stopped with). It waits with `UntilCancelledAsync` from #7403, as the file open and the backend manager do, so whatever a listing that was given up on ends with is observed.

- The listing that is left behind writes only to the process's output channel. That channel is retired by then, so a listing that ends later stops at its next write.
- The listing does not use the local database, so nothing is left using it once the backup has returned.
- It is one task per listing, not per entry.
- The listing returns no result, so `UntilCancelledAsync` gets an overload for a `Task` without one, which observes a failure of the abandoned task in the same way.

## Checked

`AbortedSourceEnumerationTests.AbortedBackupWithAStuckListingReturnsAsync` backs up a test source that gets stuck listing a folder (`listing`) or reading the attributes of a file (`attributes`), and ignores the token there. The test then:

1. aborts once the source is stuck, and expects the backup to return within 30 s with the cancellation;
2. releases the stuck call, and checks that nothing is disturbed;
3. checks that the local database file can be opened exclusively.

| | Before | After |
|---|---|---|
| Windows, `listing` | fails, "The abort did not make the backup return within 30 seconds" | passes 3 of 3 |
| Windows, `attributes` | fails, the same | passes 3 of 3 |

Before, each case was run in its own process: a backup left stuck by the first case holds on to the log, and the second case cannot set up.

The test entry is a `DispatchProxy`, so it does not name the members of `ISourceProviderEntry`.

80 related tests (`DisruptionTests`, `AbortedBackupTests`, the exclusion attribute, symbolic and hard link tests, and the progress estimate tests) passed on Windows when this was written, 1 skipped as not for this OS. On today's master, merged with #7403, #7404 and #7405, which change the same backup stages or the same file, there are no conflicts and no new warnings, and `AbortedSourceEnumerationTests`, `AbortedSourceOpenTests`, `AbortedSourceMetadataTests` and `AbortedSourceReadTests` pass (9 tests, Windows).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
