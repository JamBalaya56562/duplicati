Builds on `fix/restore-priority-file-skip-releases-waiters`, which is stacked on #7364 and the branches after it. It only touches one handler and could also go on master alone.

## What happens

The file processors share `RestoreResults.BrokenLocalFiles`. Every place that adds to it takes `lock (results)`, except the handler for a failure to copy the verified blocks of an existing file to its new name (`CopyOldTargetToNew`).

`FileBackedStringList` is not safe for concurrent use: `Add` shares the stream position and a buffer. Adding from two threads without a lock was measured to break it in 20 of 20 rounds (2 threads × 2000 adds). Either `Add` throws ("Stream serializer wrote a different set of bytes...") or reading the list later throws `OverflowException`.

A lock taken on one side only protects nothing. If this failure coincides with another file failing, one of the processors can fail on the `Add`, or the list of failed files reported at the end can fail to read. That consequence comes from reading the code: the timing cannot be arranged in a test.

## The change

The handler takes the same lock as the others.

## Testing

There is no red-to-green test, as the race cannot be set up deterministically. The evidence is the concurrency measurement above. The related restore tests (28) pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
