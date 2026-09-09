## What happens

`AbortedBackupTests.AbortedBackupWhileBlocksAreStoredReturnsAsync` failed on the Windows unit tests of #7405, which does not touch it ([run 37182116472](https://github.com/duplicati/duplicati/actions/runs/37182116472/job/111376607589)). The backup did return within 30 seconds of the abort, but it ended with `OperationCanceledException` thrown from `SqliteCommand.ExecuteReaderAsync`, and the test expects exactly `TaskCanceledException`:

```
Expected: <System.Threading.Tasks.TaskCanceledException>
But was:  <System.OperationCanceledException: The operation was canceled.
   at System.Threading.CancellationToken.ThrowIfCancellationRequested()
   at Microsoft.Data.Sqlite.SqliteCommand.ExecuteReaderAsync(...)
```

Which of the two the backup ends with depends on where the stop lands. `Controller` catches `OperationCanceledException`, so it handles both the same way. `AbortedBackupWithStalledUploadsReturnsAsync` has the same assertion.

## The change

Both assertions use `Assert.CatchAsync<OperationCanceledException>`, which accepts the exception and its subclasses. It still fails when the backup returns a result or ends with another exception.

## Checked

- To make the stop land where it did on CI, I ran the body of `AbortedBackupWhileBlocksAreStoredReturnsAsync` with the abort sent from a log listener when `RegisterRemoteVolumeAsync` logs that it starts its `INSERT`, 6 times with each assertion on Windows. In 8 of the 12 runs the backup ended with `OperationCanceledException` from `SqliteCommand.ExecuteReaderAsync` called by `RegisterRemoteVolumeAsync`, the same as on CI, and in the other 4 with `TaskCanceledException`. The old assertion failed in all 4 of its `OperationCanceledException` runs, with the same message as on CI; the new one passed all 6.
- `AbortedBackupTests` (3 tests) pass three times out of three on Windows.
- In a small NUnit 4.3.2 project, the old assertion fails for an `OperationCanceledException` from `ThrowIfCancellationRequested` and passes for a `TaskCanceledException`. The new one passes for both, and fails for a completed task and for an `InvalidOperationException`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
