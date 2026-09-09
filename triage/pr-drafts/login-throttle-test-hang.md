## What happens

Since #7339 ([`940edb5b7bbb7b198d6cd25fff669c7146841836`](https://github.com/duplicati/duplicati/commit/940edb5b7bbb7b198d6cd25fff669c7146841836) merged on 2026-09-21), the macOS unit test job has run out of its 6 hours several times, on pull requests and on the canary release branches (for example runs 35711442865 on 2026-09-22, 36163584501 for 2.4.0.102, 37118781560 for 2.4.0.103). Each time the last line in the log is `Skipped RenameCaseChangeUSNAsync(False)` from `Issue4951`, and in a run that completes, the next lines come from `NativeNotifierTests` about four minutes later. `LoginAttemptThrottleTests` sorts between the two. The ubuntu job has also run out of time since then (runs 35855513758 on 2026-09-23, 36492566225 on 2026-09-28, 37008162895 on 2026-10-02), each time after `Skipped Issue4562MacOSAclAndFileFlagsAsync` from `IssueTests`, which sorts just before `JsonWebHelperMultipartTests`; in a run that completes, `NativeNotifierTests` follows about 90 seconds later. One Windows run stopped at the same place (35737460103 on 2026-09-22).

`TooManyPendingAttemptsAreRejectedAsync` starts two attempts with `Task.Run`, waits 100 ms, and expects a third attempt to be rejected because two are pending:

```csharp
var first = Task.Run(() => throttle.VerifyAsync(() => { release.Wait(); return true; }, CancellationToken.None));
var second = Task.Run(() => throttle.VerifyAsync(() => true, CancellationToken.None));
await Task.Delay(100);
Assert.ThrowsAsync<TooManyRequestsException>(() => throttle.VerifyAsync(() => true, CancellationToken.None));
release.Set();
```

If the second attempt takes the lock before the first, it is done before the third attempt comes. Only the first is then pending, so the third is not rejected but waits for the lock, which the first holds until `release.Set()`. `Assert.ThrowsAsync` blocks until the third attempt is done, so `release.Set()` is never reached and the test never finishes.

I ran the unchanged body 300 times from a thread pool thread, where the two `Task.Run` calls are often run in the opposite order: the second attempt was done before the third in 263 runs, and in exactly those 263 runs the third attempt was still waiting for the lock after 2 seconds instead of being rejected. On the test worker thread the order is the expected one most of the time, so the test usually passes; I have not run it on macOS.

## The change

- The first attempt signals once it holds the lock, and the second attempt is started only then, called directly rather than with `Task.Run`. `VerifyAsync` counts an attempt as pending before it waits for the lock, so two attempts are pending when the third comes.
- The third attempt gets a token that is cancelled after 10 seconds, so if it does wait for the lock, the assertion fails instead of hanging.
- The first attempt is released in a `finally` block.

## Checked

The new body, run 300 times from a thread pool thread as above: the third attempt was rejected in all 300. The test passes three times out of three on Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
