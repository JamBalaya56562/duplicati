# SSH: await the SFTP rename

Branch: `fix/ssh-rename-awaited`, two commits on master 922a7c73: the fix [495eb0adf6fc155cce1c8709c654b97e0045f99c](https://github.com/JamBalaya56562/duplicati/commit/495eb0adf6fc155cce1c8709c654b97e0045f99c) and the test [fd2b982c9196632b9f64ba56005bc8262609bf18](https://github.com/JamBalaya56562/duplicati/commit/fd2b982c9196632b9f64ba56005bc8262609bf18).

## Problem

`SSHv2.RenameAsync` called:

```csharp
await Utility.Utility.WithTimeout(m_timeouts.ShortTimeout, cancelToken, ct => con.RenameFileAsync(source, target, ct).ConfigureAwait(false));
```

The lambda returns the `ConfiguredTaskAwaitable` from `.ConfigureAwait(false)`, not a `Task`. `WithTimeout` therefore takes its synchronous `Func<CancellationToken, T>` overload, which returns the awaitable without awaiting it. The rename ran in the background with nobody observing it. `RenameAsync` returned before the rename finished, and any error from the server was lost.

## Change

Move `.ConfigureAwait(false)` outside, so the lambda returns the `Task` and the async overload awaits it:

```csharp
await Utility.Utility.WithTimeout(m_timeouts.ShortTimeout, cancelToken, ct => con.RenameFileAsync(source, target, ct)).ConfigureAwait(false);
```

## Testing

Added `SshTests.TestSSHRenameReportsErrors` to the SSH live tests (the SFTPGo container the CI SSH job already runs, `ClassName~SshTests`). It renames an uploaded file and checks the listing, then renames a file that does not exist and expects an exception. Run locally with Docker Desktop:

- with the fix: passed
- without it: `Renaming a file that does not exist did not fail`

Before that test existed, I tested by hand against an SFTP server (`atmoz/sftp` in Docker, published on localhost:2222), calling `SSHv2.RenameAsync("missing.txt", "renamed.txt")` from a small console program:

- master: returned without error, although `missing.txt` does not exist
- this branch: `SftpPathNotFoundException: No such file`
- this branch, with `missing.txt` on the server: returns normally, and the server then has `renamed.txt`

I found this while counting the call sites of the synchronous `WithTimeout` overloads by marking them `[Obsolete]` and building the solution. The backend change merges cleanly with `fix/ssh-list-timeout`. Both branches add a test to `SSH/SSHTests.cs`, with the same two helpers (`StartSftpgoAsync`, `CreateBackend`) at the same place, so whichever merges second has a conflict there: keep the helpers once and both test methods.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
