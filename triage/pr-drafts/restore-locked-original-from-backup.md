# Restore from the backup when the original file cannot be read

Fixes #5573

With `--restore-with-local-blocks`, a restore reads the blocks it can from the file at the original path. That file is only a shortcut: every block can also come from the backup. When another program holds it, as it can while the file is backed up from a snapshot (the case in #5573), the restore did not fall back to the backup.

In 2.0.9.107 this gave a warning. With the current restore engine it is worse: `VerifyLocalBlocksAsync` opened the original with no error handling, and a failed read of it was rethrown, so the restore itself failed:

```
System.IO.IOException : The process cannot access the file '...\locked.bin' because it is being used by another process.
System.IO.IOException : The process cannot access the file because another process has locked a portion of the file. : '...\locked.bin'.
```

With this change:

- An original that cannot be opened is skipped, as an original that does not exist already is, and all its blocks come from the backup.
- When a read of the original fails, for example on a range another program has locked, the blocks read so far are kept and the rest come from the backup. Such a failure no longer marks the restored file as broken, as the restored file is not at fault.
- Both are logged at the verbose level.

## Testing

New `RestoreLockedOriginalTests`, which back up a file of four 100 KB blocks and restore it to another folder with `--restore-with-local-blocks` while the original is held:

| test | master | with the change |
|---|---|---|
| `AnOriginalOpenedExclusivelyIsRestoredFromTheBackupAsync` (`FileShare.None`) | the restore fails with the first error above | restored, no warnings, same content |
| `AnOriginalWithALockedRangeIsRestoredFromTheBackupAsync` (Windows; the second and third blocks locked with `FileStream.Lock`, so the first block comes from the original) | the restore fails with the second error above | restored, no warnings, same content |

`RestoreLockedOriginalTests`, `RestoreNoOverwriteAppendedTests`, `RestoreFileFailureTests`, `RestoreHandlerTests`, `RestoreDryRunVerificationTests`, `RestoreAllFilesTests`: 64 passed on Windows. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
