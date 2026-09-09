The Windows unit tests crashed twice with an `AccessViolationException` in `Disk.Windows.ReadBytesAsync`, below `PartitionSourceEntry.Enumerate` ([job on 10-30](https://github.com/duplicati/duplicati/actions/runs/41145202038/job/124368564061), [job on 11-09](https://github.com/duplicati/duplicati/actions/runs/42587254531/job/129059918640)). Of the 126 failed test runs since 09-15, only these 2 crashed this way, and both came after #7520 was merged on 10-23.

## Cause

#7520 made `FileEnumerationProcess.RunAsync` stop waiting for its listing when the operation is aborted, so a stuck source cannot hold up "Stop now". It also stopped waiting when its own token was cancelled.

- The backup cancels the file counter's token when it is done, so the counter's listing was left running.
- The backup then disposed the source while the listing still read it.
- A disk image source frees the buffer it reads into when it is disposed (`Disk.Windows.Dispose`), so the listing can copy from freed memory.

With a fake source whose counting listing takes 3 seconds, and a backup that is not aborted:

| master | the backup returned after | listings that used the source after it was disposed |
|---|---|---|
| before #7520 ([638e27658](https://github.com/duplicati/duplicati/commit/638e2765883b60ff52a46ea1716edd0e39165685)) | 3.2 s | 0 |
| [d6dcdd0c7](https://github.com/duplicati/duplicati/commit/d6dcdd0c734f99d9c5101e55cd3dc287b191e5e9) | 0.3 s | 1 (3 runs out of 3) |

The step from "copies from freed memory" to the crash in CI is inferred from the stack traces and the code. It was not reproduced with a real disk.

## The change

Only an aborted operation (`taskreader.ProgressToken`) stops waiting. A listing that is only no longer wanted is waited for, as before #7520: it stops at the next entry. The abort case of #7520 is unchanged.

#7759 also makes the disks safe to dispose while a read is running, for the listings that an abort still leaves behind.

## Testing

New `AbortedSourceEnumerationTests.AListingIsWaitedForUnlessTheOperationIsAbortedAsync`, which runs `FileEnumerationProcess.RunAsync` on a source whose listing gets stuck:

| case | before this change | this branch |
|---|---|---|
| `(False)`: the token is cancelled | **fail**: "The process returned while the listing was still reading the source" | pass |
| `(True)`: the operation is aborted | pass | pass |

On Windows, `AbortedSourceEnumerationTests` and `DisruptionTests.StopNow` / `StopAfterCurrentFile`: 16 passed. No warnings in the changed files.

Refs #6461

🤖 Generated with [Claude Code](https://claude.com/claude-code)
