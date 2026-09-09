Repository: duplicati/documentation
Branch: `docs/use-move-for-put-alone` (from `main@upstream` ec2f90d01101)
Title: Drop --disable-streaming-transfers from the move-for-put advice
Companion of the duplicati branch `docs/use-move-for-put-help` (the same correction in the option's help text); this docs change does not depend on it, the text matches what the current releases do.

## Summary

`backup-destinations/standard-based-destinations/file-destination.md` said to set `--disable-streaming-transfers` together with `--use-move-for-put`. Since duplicati/duplicati@012aeed7de6946fd8b60ada674c5071de4b72f42 ("Add dynamic streaming toggle"), the file backend turns off streaming by itself when `--use-move-for-put` is set, so the second option is no longer needed.

- The paragraph now says that `--use-move-for-put` alone is enough, and why no progress is shown.
- A note keeps the old advice for Duplicati 2.2.0.3 and earlier. I checked the file backend in each release tag: the change is in 2.2.1.0 (beta) and 2.3.0.0 (stable), and not in 2.2.0.0 to 2.2.0.3.

A test in the duplicati branch backs up through the file backend with only `--use-move-for-put` and checks that the volumes are handed over as files, not streamed.

Commit: [d02e83770cf62fd7a9772ad304e74d4b13caf7c4](https://github.com/JamBalaya56562/documentation/commit/d02e83770cf62fd7a9772ad304e74d4b13caf7c4)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
