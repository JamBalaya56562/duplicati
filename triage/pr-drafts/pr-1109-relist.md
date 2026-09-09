In #7665, a backup to pCloud failed at the final verification with `Found 1 files that are missing from the remote storage, please run repair`. The dlist file had just been uploaded, and a listing a few seconds later showed it. Some destinations list a new file only after a delay.

## The change

In `FilelistProcessor.RemoteListAnalysisAsync`, when a volume in the `Uploaded` state (uploaded, but not yet seen in a listing) is missing from the listing, the destination is listed again before the volume is reported as missing:

- up to `--number-of-retries` more listings, with `--retry-delay` between them (following `--retry-with-exponential-backoff`);
- `--number-of-retries=0` turns it off;
- the wait is logged at the information level (`UploadedFileNotListed`);
- the database is compared with the last listing only once;
- a volume that was already `Verified` in an earlier listing is still reported at once, so a file that really disappeared does not make the backup wait.

I used the existing retry options rather than a new option. If a separate option is preferred, I can change it.

## Testing

`DeterministicErrorBackend` can now hide names from a listing (`ListingFilter`). New tests in `UploadedFileMissingFromListingTests`:

| test | master | this branch |
|---|---|---|
| `ADlistListedOnlyLaterDoesNotFailTheBackupAsync` | **fail**: the error from #7665 | pass |
| `ADlistThatStaysMissingFailsAfterTheRetriesAsync(2, 3)` | **fail**: one listing, not three | pass |
| `ADlistThatStaysMissingFailsAfterTheRetriesAsync(0, 1)` | pass | pass |
| `AFileSeenInAnEarlierListingIsNotListedAgainAsync` | pass | pass |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `UploadedFileMissingFromListingTests`, 4 passed. Before the rebase, the 5 classes that handle missing files (`RepairWithMissingRemoteFiles`, `Issue1282`, `RecreateWithEmptyFilelistTests`, `CompactAfterInterruptedUploadTests`, `DlistFilesetTimeTests`), 57 passed, the longest in 6 s, so the default 5 retries of 10 s were not waited for. No warnings in the changed files.

Not tested with pCloud itself, so this refers to #7665 rather than closing it.

Refs #7665

🤖 Generated with [Claude Code](https://claude.com/claude-code)
