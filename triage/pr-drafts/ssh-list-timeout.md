# SSH: apply the list timeout to SFTP listings

Branch: `fix/ssh-list-timeout`, two commits on master 922a7c73: the fix [7d21280231a3fb06afc8fd7a6cffb47cb971ba1e](https://github.com/JamBalaya56562/duplicati/commit/7d21280231a3fb06afc8fd7a6cffb47cb971ba1e) and the test [fa44fd16f4e5def1fbd1eafd49d4a297d41ff9b7](https://github.com/JamBalaya56562/duplicati/commit/fa44fd16f4e5def1fbd1eafd49d4a297d41ff9b7).

## Problem

`SSHv2.ListAsync()` and `SSHv2.ListAsync(path)` wrapped `con.ListDirectoryAsync(path, ct)` in `Utility.WithTimeout(ListTimeout, ...)`. `ListDirectoryAsync` returns an `IAsyncEnumerable` without sending anything, so `WithTimeout` took its synchronous overload and timed only the creation of the enumerable. The listing itself ran in the `await foreach` that followed, with no timeout. A server that stopped answering kept the listing waiting for as long as the connection stayed open (or until `ssh-operation-timeout`, if set).

## Change

Read the listing inside the timeout: `ct => con.ListDirectoryAsync(path, ct).ToListAsync(ct).AsTask()`. SSH.NET's `ListDirectoryAsync` takes the token, so a timeout really stops the listing; nothing is left running in the background. Both list methods are changed.

The entries are now collected before they are returned, instead of being streamed. Many other backends already do the same inside their list timeout.

## Testing

Added `SshTests.TestSSHListTimesOutWhenServerStopsAnswering` to the SSH live tests (the SFTPGo container the CI SSH job already runs, `ClassName~SshTests`). It lists once while the server answers, then pauses the container and lists again with `list-timeout=5s`, expecting an exception within 60 seconds. Testcontainers 3.4 has no pause, so the test pauses the container through the Docker client Testcontainers is built on (`TestcontainersSettings.OS.DockerEndpointAuthConfig`). The container is unpaused before it is stopped. Run locally with Docker Desktop:

- with the fix: passed
- without it: `The listing did not return within 60 seconds with a list timeout of 5 seconds`

Before that test existed, I tested by hand against an SFTP server (`atmoz/sftp` in Docker, published on localhost:2222) from a small console program with `list-timeout=2s`. The program lists once, then the server container is paused with `docker pause`, and the program lists again:

- master: the second listing did not return until the server was resumed about 60 s later
- this branch: the second listing threw `TimeoutException` after 2.0 s. The first listing, before the pause, returned normally.

I found this while counting the call sites of the synchronous `WithTimeout` overloads by marking them `[Obsolete]` and building the solution. The backend change merges cleanly with `fix/ssh-rename-awaited`. Both branches add a test to `SSH/SSHTests.cs`, with the same two helpers (`StartSftpgoAsync`, `CreateBackend`) at the same place, so whichever merges second has a conflict there: keep the helpers once and both test methods (checked with a temporary `jj new` merge).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
