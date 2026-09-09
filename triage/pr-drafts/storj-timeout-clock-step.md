# Allow the Storj idle timeout test one step of the tick count

`StorjTransferTimeoutTests.ATransferThatStopsMovingTimesOut` failed once on ubuntu in #7655, which does not touch Storj:

```
Assert.That(sw.Elapsed, Is.GreaterThanOrEqualTo(IdleTimeout))
Expected: greater than or equal to 00:00:01
But was:  00:00:00.9995078
```

`WaitForTransferAsync` counts the idle time with `Environment.TickCount64`, and the test measures it with a `Stopwatch`. The tick count moves in steps, so it can reach the timeout a step before the stopwatch does. Measured with a small program that waits until the tick count has moved 100 ms:

| | step of `TickCount64` | shortest stopwatch time |
|---|---|---|
| Linux (WSL) | 4 ms | 96.8 ms |
| Windows | 15 to 16 ms | 103.5 ms |

The test now allows 50 ms below the timeout. The other timing assertion in the file already allows 300 ms.

## Testing

`StorjTransferTimeoutTests`: 7 passed on Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
