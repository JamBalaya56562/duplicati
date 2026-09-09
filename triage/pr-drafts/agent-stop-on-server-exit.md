## Summary

The Agent runs the hosted server in a loop that restarts it after a crash. The loop also restarted the server when `Server.Program.Main` returned normally. `Main` only returns normally after the exit event was signalled (`shutdown` on the ping-pong channel, Ctrl+C, or the webserver terminating), and that event is a `CancellationTokenSource` that cannot be reset. The restarted server therefore returned as soon as it got to waiting on the exit event, and the loop spun without any delay instead of letting the Agent stop.

The loop now also stops when the exit event has been signalled. Restarts after an exception, while the exit event is not signalled, work as before.

To test the loop, `RunServerAsync` is `internal` (with `InternalsVisibleTo("Duplicati.UnitTest")`) and takes an optional delegate that replaces `Server.Program.Main`. The production call site passes nothing and still runs `Server.Program.Main`.

## Testing

- New `AgentRunServerTests.ServerExitAfterExitSignalStopsTheLoop` runs the loop with a server stand-in that signals the exit event and returns.
  - Without the fix: fails, the loop called the server 8,108,083 times in 5 seconds.
  - With the fix: passes, the server is called once and the loop returns.
- `dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --filter FullyQualifiedName~AgentRunServerTests` builds with 0 warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
