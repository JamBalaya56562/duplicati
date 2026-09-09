## Summary
#1809 asked for a check of every dlist and dindex file that does not download the dblock files. Since #5037 this is `test all --full-remote-verification=ListAndIndexes`. No test used that value. This PR only adds a test.

## Testing
- New test `Issue1809.ListAndIndexesChecksEveryListAndIndexWithoutTheBlocksAsync`. It makes a backup with several dblock files and runs `test` on all samples with `ListAndIndexes`, counting what is downloaded. It checks that every dlist and dindex file is downloaded and no dblock file is. With `ListAndIndexes` taken out of the check that stops before the dblock files, it fails: 4 dblock files are downloaded. On master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
