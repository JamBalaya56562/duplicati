Since #7605 was merged, the `Unit tests (windows-latest)` job has hit the 6 hour limit on every pull request. The PR's own run was already cancelled that way. Linux and macOS still pass in about an hour.

## Cause

`ControllerPipeHandshakeTests.TokenIsVerifiedOverThePipe` waits on itself on Windows:

- It writes the token and the next message to the client end of the pipe, and only then reads them from the server end.
- `NamedPipeServerStream` is created without buffer sizes, so on Windows the pipe has no buffer, and a write only returns once the other end has read it.
- The first write (`ControllerPipeHandshake.WriteToken`) is synchronous, so the test's 10 second cancellation token cannot stop it.

On Linux and macOS the pipe is a Unix domain socket with a buffer, so the test passes there.

The controller itself is not affected. There the controller process writes the token while the server process is already reading it.

## Evidence

- On `windows-latest`, the unit tests of current master (31bf7aa0225f095de70020700224d3f229dcfe65) with `--blame-hang-timeout 15m` stopped after 15 minutes with `The test running when the crash occurred: Duplicati.UnitTest.ControllerPipeHandshakeTests.TokenIsVerifiedOverThePipe` ([run on my fork](https://github.com/JamBalaya56562/duplicati/actions/runs/41027497660)).
- Locally on Windows with `--blame-hang-timeout 10m`, the run was aborted on the same test, the last test started in the blame sequence.
- A probe on Windows, writing to the client end of a connected pipe with nobody reading the server end. It gave up after 10 seconds:
  - `WriteToken`, which writes and flushes: did not return.
  - A plain `Write` without flush: did not return either, so it is the missing buffer, not the flush.
  - `WriteToken` while `ReadTokenAsync` was already running on the server end: returned at once, and the token was read.

## Change

Only the test. The writes run on another task while the test reads, as the controller process does. The test checks the same things as before: the token matches, and the message after the token line is left in the stream.

## Testing

On Windows, with `--blame-hang-timeout 5m`:

- `ControllerPipeHandshakeTests` and `IPCTests`: 7 passed. `TokenIsVerifiedOverThePipe` took 12 ms.
- `BorderTests.Run10kIPCAsync` also passed in an earlier run of the same change.

The Windows unit test job of this pull request is the check for the whole suite.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
