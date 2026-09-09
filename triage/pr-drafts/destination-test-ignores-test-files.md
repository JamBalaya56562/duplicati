Branch: `fix/destination-test-ignores-test-files` (on top of `fix/connection-test-unique-file` 6500be45d3a9499830e09aa826d3e60da981b2ed, which is on master 922a7c73750fd04295ed3bae8ebc3f8832ab227b)
Title: Do not count test files when reporting if a destination folder is empty
When to open: after `fix/connection-test-unique-file` is merged. Rebase onto master first (`jj rebase -s fix/destination-test-ignores-test-files -d master@upstream`); the branch then has only this commit. It uses the test file name form that branch introduces.

## Summary

After a destination test, `POST /api/v2/destination/test` lists the destination folder to report `FolderIsEmpty`, `FolderContainsBackupFiles` and `FolderContainsEncryptedBackupFiles`. When another test of the same destination is still running, its test file (`duplicati-access-privileges-test-<guid>.txt`) is in that listing, and the folder was reported as not empty although it only holds that test file.

The listing now skips test files, both the old fixed name and the current form (`BackendExtensions.IsTestFileName`). The check in `BackendExtensions` that removes left over test files uses the same helper.

Commit: [7a6017051c0fbd7f4a0bf459a7aebeeeb3f61df9](https://github.com/JamBalaya56562/duplicati/commit/7a6017051c0fbd7f4a0bf459a7aebeeeb3f61df9)

## Testing

- New `ServerApiIntegrationTests.DestinationTestIgnoresTestFileOfAnotherTestV2_Async`: a `file://` folder that only holds a test file of another (still running) test; `POST /api/v2/destination/test` should report `FolderIsEmpty: true` and leave that file alone.
  - Before (with `DestinationVerify.cs` from `fix/connection-test-unique-file`): fails, `A test file of another test should not count as a file in the folder. Expected: True But was: False`.
  - After: passes.
- `DestinationAutoCreateAcceptsExistingFolderV2_Async` and the six `BackendTestPermissionsTests` still pass (8 passed), also after rebasing onto master 922a7c73.
- The Playwright suite against a server published from this branch: see the Playwright update PR (`backup and restore flow` passes, the earlier "Test connection failed ... being used by another process" no longer appears).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
