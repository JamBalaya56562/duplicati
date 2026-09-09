## Summary
`Test_RawDisk_DisposeWhileReading_DoesNotCrash_Async` let each of its four readers make 50 reads, and disposed the disk after 200 ms. On a fast runner all the reads ended before the dispose, so no reader was stopped by it, and the test failed with `Expected: 4`, `But was: 0`. It failed this way on macOS in the CI of #7957, which does not touch this code. Each reader now reads until the disk is disposed, with a deadline of 60 seconds that only ends the readers if the dispose does not stop them.

Only the test changes.

## Testing
- The test needs administrator privileges and is skipped locally. On the fork, the unit tests ran with the change: all jobs passed in [run 44967471373](https://github.com/JamBalaya56562/duplicati/actions/runs/44967471373), and the macOS unit tests, where this test failed before, reported `Failed: 0, Passed: 4256`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
