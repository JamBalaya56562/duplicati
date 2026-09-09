Branch: `fix/connection-test-unique-file` (from master 922a7c73750fd04295ed3bae8ebc3f8832ab227b)
Title: Use a unique test file for each destination test
Merge order: independent. `fix/destination-test-ignores-test-files` is stacked on this branch. The web UI side (ngclient: Continue starts a second test while the "Create folder" test is still running) is a separate change in duplicati/ngclient.

## Summary

Every destination test (`BackendExtensions.TestReadWritePermissionsAsync`, used by the `TestAsync` of all backends) wrote, read and deleted a file with the same name, `duplicati-access-privileges-test.txt`. When two tests of one destination run at the same time, one test deletes or holds the other's file. The web UI does this: after "Create folder" it runs a test with `AutoCreate`, and pressing Continue before that finishes starts a second test. The Playwright `backup and restore flow` hit it on Windows:

```
Test connection failed
Error on deleting file: duplicati-access-privileges-test.txt, error: The process cannot access the file '...\playwright_destination\duplicati-access-privileges-test.txt' because it is being used by another process.
```

The network trace of that run shows the two `/api/v2/destination/test` requests overlapping (`AutoCreate: true` started at 42.474 and took 656 ms, `AutoCreate: false` started at 42.811), and the second one returned the error above.

Each test now uses its own file, `duplicati-access-privileges-test-<guid>.txt`. The check at the start that removes test files left over from earlier tests now removes:

- a file with the old fixed name, as before, and
- a file with the new form whose time is known and more than an hour old.

A younger file, or one without a time, may belong to a test that is still running, so it is left alone.

Not changed: after the test, the v2 destination test endpoint lists the folder to report `FolderIsEmpty`; a test file of another test that is running at that moment still counts as a file there (as the fixed name did before).

Commit: [6500be45d3a9499830e09aa826d3e60da981b2ed](https://github.com/JamBalaya56562/duplicati/commit/6500be45d3a9499830e09aa826d3e60da981b2ed)

## Testing

- New `BackendTestPermissionsTests.TwoTestsOfTheSameDestinationAtOnceBothSucceed_Async`: two backends share one in-memory destination; the second test runs completely while the first has written its file and not yet read it back.
  - Before: `TestAfterConnectException : Error reading file: duplicati-access-privileges-test.txt` (the second test removed the first test's file).
  - After: both pass and no test file is left.
- New `LeftoverTestFilesAreRemovedButNotThoseOfRunningTests_Async`: the old fixed name and an old file of the new form are removed; a recent one, one without a time and a backup file are kept.
  - Before: fails (the old file of the new form is left).
  - After: passes.
- The four existing tests in `BackendTestPermissionsTests` pass before and after (`dotnet test --filter "FullyQualifiedName~BackendTestPermissionsTests"`: 6 passed).
- With the real File backend on Windows: a small program loads the Duplicati assemblies from a build and runs two `TestAsync(true)` calls on the same folder at the same time, 200 times.
  - Master build: 221 of 400 tests failed (`Error on deleting file ... being used by another process`, `Error writing file ...`, `Error reading file ... Could not find file`, and others).
  - This branch: 0 of 400 failed, and no test file was left in the folder.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
