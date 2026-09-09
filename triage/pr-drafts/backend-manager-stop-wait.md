# Wait long enough for the backend queue runner to stop

Disposing the backend manager gave its queue runner one second to stop, and warned "Backend manager queue runner did not stop" otherwise. The runner closes the pooled backends before it stops, so a backend that takes a while to disconnect, or a briefly stalled machine, turned a successful operation into one with a warning.

This showed up as a flaky unit test on Windows: `ZeroLengthMetadataTests.PurgeRewritesEveryAffectedFilelistAsync` failed in the CI of #7663 with that warning and nothing else, so no transfer was still running.

The change ([83252317](https://github.com/duplicati/duplicati/commit/83252317da65c6dcc889f8c5867aa96b71572063)):
- `BackendManager.Dispose` now waits up to ten seconds instead of one. The warning is kept for a runner that still does not stop.
- A new test, `BackendManagerShutdownTests`, backs up to a file backend whose dispose takes 1.5 seconds. It fails on master with the warning and passes with the change.

Measured locally: after the request channel is retired, the runner stopped within 2-8 ms in all 34 operations of `ZeroLengthMetadataTests`, so the longer wait is only reached when something is slow. The stop and cancellation tests in `DisruptionTests` took the same time with one and ten seconds.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
