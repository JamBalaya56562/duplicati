After a destination test, `POST /api/v2/destination/test` lists the destination folder to report `FolderIsEmpty`, `FolderContainsBackupFiles` and `FolderContainsEncryptedBackupFiles`. When another test of the same destination is still running, its test file (`duplicati-access-privileges-test-<guid>.txt`, since #7600) is in that listing, so the folder was reported as not empty although it only held that test file.

## The change

The listing in `DestinationVerify.cs` now skips test files, using `BackendExtensions.IsTestFileName`, which matches both the old fixed name and the current form.

## Testing

New `ServerApiIntegrationTests.DestinationTestIgnoresTestFileOfAnotherTestV2_Async`: a `file://` folder that only holds a test file of another test that is still running. `POST /api/v2/destination/test` must report `FolderIsEmpty: true` and leave that file alone.

- Before: fails with "A test file of another test should not count as a file in the folder. Expected: True But was: False".
- After: passes.

Run again after rebasing onto master [c16a28aa8](https://github.com/duplicati/duplicati/commit/c16a28aa8cfb8564fa23b9caa5499b33711aae80), in one build with the other branches I am opening today: 48 tests passed, among them the test above. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
