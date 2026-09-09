Fixes #4044

The recovery restore keeps up to `--max-open-archives` archives open, 200 by default. When the system allows fewer open files than that plus what the runtime needs, opening an archive or moving a restored file fails with "Too many open files", and every file restored after that fails too.

When that happens, the restore now closes the older half of the open archives, keeps no more than the rest open from then on, and restores the file again. The out-of-files error is recognised by its `HResult` (0x80070004 on Windows, errno 23 or 24 elsewhere).

Restoring a file again means reading its blocklist hashes again, but the file list is read as a stream and a second read failed with `Invalid JSON`. The hashes are now collected into a list for each file first.

## Testing

- New `RecoveryToolOpenFilesTests` (Linux and macOS only) lowers `RLIMIT_NOFILE` to the current count + 40. Under WSL, on an older master, it failed without the change (status 1) and passed with it. It is skipped on Windows, so on the current master it is only run by this PR's CI.
- A manual reproduction with `ulimit -n 256` and 320 dblock files, on the same older master, restored 163 of 400 files before the change and 400 of 400 after it, with matching contents.
- On Windows on the current master, the `RecoveryTool` tests: 15 passed, the new test skipped. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
