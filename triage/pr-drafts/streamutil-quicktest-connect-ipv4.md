## Problem

`QuickTest`'s `TestTimeoutStream` uploads 100 MB through a `TimeoutObservingStream` with `ReadTimeout = 3000`, to check that a transfer that keeps moving does not time out. The read timer starts when `ReadTimeout` is set, before the request is sent, so everything up to the first read counts against those 3 seconds.

The sink in `SocketHelper` listens on IPv4 only (`IPAddress.Any`), but the test connects to `http://localhost:12345/`. `localhost` resolves to `::1` first, and on Windows a refused connection takes about two seconds before the client falls back to `127.0.0.1`. Measured on Windows 11 with a minimal IPv4-only listener:

```
connect localhost: 2119 ms
connect 127.0.0.1: 1 ms
connect localhost: 2048 ms
connect 127.0.0.1: 4 ms
```

With logging added around `ReadTimeout` and `Read`, the first read of the test came 2156–2453 ms after the timer started on `main`, leaving 0.5–0.8 s for the HTTP and digest round trips. When a run went over, the timeout fired while the request was still waiting for its connection, before any data was read, and the test ended with an unhandled `TaskCanceledException`. On `main` this happened in 1 of 51 runs on this machine.

## Change

Connect to `127.0.0.1`, the address the sink listens on. The timeout semantics of `TimeoutObservingStream` are unchanged; the time before the first read now only covers the connection and the authentication round trip.

## Testing

On Windows 11 with .NET 10, the first read now comes 125–797 ms after the timer starts (17 runs, measured on a logging build that also contained the fix for #6, which does not touch this path), against 2156–2765 ms before. This branch passed 17 of 17 runs, interleaved with `main`.

Linux and macOS refuse the IPv6 connection at once, so this mostly affects Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
