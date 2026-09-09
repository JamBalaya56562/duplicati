Title: Google Drive: delete every copy of a name, including one left by an interrupted upload

Branch: `fix/gdrive-duplicate-after-timeout`

---

A Google Drive upload that times out on the client can still be finished by Drive. The retry cannot see that file yet, so it creates a second one with the same name. When the retry succeeds, the backend's cache holds only the new file. `DeleteAsync` read the name from that cache and removed only that copy, so the first one stayed on the destination for good.

This shows up in the Backend Live Tests for Google Drive. An upload hits the 60 s read-write timeout, the retry succeeds, and after cleanup the next run finds one file left in the folder (`Remote folder contains 1 file(s), aborting`), for example in job 119147797034.

### Changes

- `DeleteAsync` now asks Drive again for every file with the name, and deletes those files together with the cached entries. The cached entries are kept because a file that was just created may not be listed yet.
- Cost: one extra list request (filtered by title) per delete.

This does not stop the duplicate from being created. Listing (one entry per name) and reads (newest copy) already handle duplicates since #5846. This change makes sure a delete does not leave a copy behind.

### Tests

`GoogleDriveInterruptedUploadTests` stubs `HttpMessageHandler`. In the stub, the first upload session is cut off with `TaskCanceledException`, and the file it created only shows up in later listings. The tests check the DELETE requests the backend sends:

- `ADeleteAfterARetriedUploadRemovesTheInterruptedCopy`: fails on master (`Expected: equivalent to < "id-1", "id-2" > But was: < "id-2" >`), passes with this change.
- `ADeleteAfterAnEarlierListingRemovesTheInterruptedCopy`: the BackendTester order (a listing between the upload and the delete). Same result: fails on master, passes with this change.
- `ADeleteOfASingleUploadRemovesOneFile`: passes both before and after. A name held once is still deleted with one request.

The existing `GoogleDrive*` unit tests still pass. Not checked against the real Google Drive.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
