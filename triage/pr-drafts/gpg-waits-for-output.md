GPG only finishes a volume after it has read all of it. On large volumes or busy disks that takes longer than the fixed five seconds `GPGStreamWrapper.Dispose` waited, so the backup failed with "Failure while invoking GnuPG, program won't flush output" (#2566). The thread copying GPG's output then kept writing into the output file after the caller had closed it, and the resulting `ObjectDisposedException` on a bare thread crashed the process (#2443).

Changes:
- `GPGStreamWrapper` waits for the copy and for GPG without a time limit.
- GPG's error output is read while GPG runs, so GPG cannot stall on a full stderr pipe and stop reading its input.
- The copy runs as a `Task`; a failure (e.g. disk full, or GPG exiting early during decryption) is rethrown from `Dispose` instead of crashing the process.
- When the copy fails, or GPG fails to start, the GPG process tree is killed instead of being left behind.

Tests: `GPGEncryptionTests` drives the module with a stand-in for gpg (a `.cmd`/PowerShell script on Windows, `sh` elsewhere) that echoes its input after the passphrase line. Before this change, the slow-GPG and stderr tests failed, and the two failure tests crashed the test host with an unhandled exception from `GPGEncryption.Runner`. All six pass on Windows and Linux.

Fixes #2566
Fixes #2443

🤖 Generated with [Claude Code](https://claude.com/claude-code)
