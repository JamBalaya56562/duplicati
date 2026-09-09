Fixes #7413

## What happens

With `jottacloud-threads` above 1 (4 by default), `ParallelGetAsync` downloads a file in chunks, several at a time. Each pass of its loop takes one finished chunk task with `Task.WhenAny`, removes it from the list, and writes the chunks that are next in order. The loop ran while

```csharp
chunks.Count > 0 || tasks.Any(t => !t.IsCompleted) || completedChunks.Any()
```

If the remaining chunk tasks all finished while an earlier chunk was being written, then no chunk was left to start, no task was still running, and no finished chunk was waiting, so the loop ended with those tasks never collected. The final check then threw "Stream position mismatch after download", as in the issue. It depends on timing, which is why it only happens sometimes.

## The change

The loop runs while any task is still in the list (`tasks.Count > 0`), so every chunk task is collected, finished or not. This is the fix suggested in the issue.

To test the backend without the network, it gets an `internal` constructor that takes an `HttpClient`, which is passed to `JottacloudAuthHelper`, as other backends do.

## Checked

`JottacloudParallelGetTests.ChunksThatFinishWhileTheFirstIsWrittenAreStillWritten_Async` (new) answers the backend from a stub: four chunks, four threads, and the writing of the first chunk waits until the other three have been sent. It failed with "Stream position mismatch after download" three times out of three before the change, and passes three times out of three after it. `TheLoaderStillFindsTheTwoArgumentConstructor` checks that the backend loader still finds the public constructor.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
