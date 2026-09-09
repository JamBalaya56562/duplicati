## Summary

The Agent declares `--ping-pong-keepalive` and stores it in `CommandLineArguments.PingPongKeepalive`, but the value was never added to the arguments it hands to the server it hosts. The server's ping-pong responder (read a line from stdin, answer `pong`, act on `shutdown`) therefore never started, whatever the option was set to. This has been the case since the option was introduced together with the Agent.

This PR forwards the option alongside the other settings the Agent passes on. The default stays `false`, so nothing changes for existing setups. The Windows service runs the Agent in-process and does not use this path.

To make the forwarding testable, the argument list is moved into `BuildServerArguments`, which is `internal` (with `InternalsVisibleTo("Duplicati.UnitTest")`). The behaviour of `StartLocalServerAsync` is otherwise unchanged.

## Testing

- New `AgentServerArgumentsTests.PingPongKeepaliveIsPassedToServer(true/false)` builds the server arguments and parses them with `FilterCollector.ExtractOptions` + `Utility.ParseBoolOption`, the same way `Server.Program.Main` does.
  - Without the fix: both cases fail with "The option was not passed on to the server".
  - With the fix: both cases pass.
- `dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --filter FullyQualifiedName~AgentServerArgumentsTests` builds with 0 warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
