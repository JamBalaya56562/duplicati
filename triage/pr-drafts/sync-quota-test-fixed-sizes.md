`TestRemoteSynchronizationQuotaCheckFailsAsync` failed the Windows unit tests of #7798, which does not touch the remote synchronization:

```
Remote synchronization should fail due to insufficient quota.
  Expected: not equal to 0
  But was:  0
```

## Cause

The test synchronizes to a test backend with 1 KiB free and expects the quota check to stop it. The check stops only when the files to copy are larger than the free space (`RemoteSynchronizationRunner.cs`). The test made 5 files with random sizes from 1 to 2047 bytes, so sometimes they added up to 1 KiB or less. The check then passed, and the synchronization succeeded.

The log of the failed run has no "Not enough free space in destination" line, while a passing run has one. With 3 files under 300 bytes, the test fails the same way every time. The chance per run is about 1 in 3800 (0.026%, from a simulation of 20 million runs and the closed form).

## The change

The 5 files now have 2 KiB each, 10 KiB in all. No other test depends on the size of random files against a quota.

## Testing

On Windows, the two quota tests passed 10 out of 10 runs, and all 76 tests in `ToolTests` pass. No new warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
