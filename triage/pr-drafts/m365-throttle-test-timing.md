Title: Make the mailbox throttling tests independent of the runner's speed

## What happens

`ThrottlingHoldsBackAllRequestsForTheMailboxAsync` (#7782) requires the requests for another mailbox and for a drive to reach the server within 550 ms of the throttled answer. On a busy runner they can take longer, and the test fails with "Another mailbox is not held back" although nothing was held back. The test also waits a fixed 50 ms for the helper to handle the throttled answer before it sends the request that should be held back.

On Linux with the test pinned to one CPU next to three busy loops, it failed in 5 of 50 runs, for example:

```
Another mailbox is not held back
Expected: less than 00:00:00.5640058
But was:  00:00:01.0658147
```

Without the load it passed 40 of 40 runs.

The Ubuntu unit test job of #7782 failed, but its log is no longer available, so I could not confirm that this was the test that failed there.

## The change

Only the test file changes.

- The tests wait for the `Office365APIThrottled` log entry, which `SendWithRetryAsync` writes after it has held back the mailbox, instead of a fixed delay.
- Whether other requests are held back is checked in a new test, `ThrottlingDoesNotHoldBackOtherRequestsAsync`. It uses a Retry-After of a minute and cancels the waiting requests at the end, so it only checks which requests reached the server. A request that is held back by mistake makes it fail after 10 seconds.
- `ThrottlingHoldsBackAllRequestsForTheMailboxAsync` keeps the lower bounds (the held back request and the retry come after the wait), which a slow machine cannot break.

## Checked

- Under the same load, the 12 tests in `Office365MailboxGateTests` passed in 50 of 50 runs, and in 20 of 20 without it. They also pass on Windows.
- The tests still find a broken gate:
  - When the throttling is not reported to the gate, both throttling tests fail.
  - When all mailboxes share one throttle, the new test fails with a `TimeoutException`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
