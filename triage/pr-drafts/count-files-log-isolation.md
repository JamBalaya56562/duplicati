## What happens

While a backup runs, `CountFilesHandler` goes through the same source paths a second time to count the files for the progress bar. Every message about a path that the enumeration logs was therefore logged twice: once from the backup's own pass and once from the count pass. With a folder that cannot be read, the backup reports two identical warnings:

```
[Warning-Duplicati.Library.Main.Operation.Backup.FileEnumerationProcess-PermissionDenied]: Excluding path due to permission denied: C:\...\locked\
[Warning-Duplicati.Library.Main.Operation.Backup.FileEnumerationProcess-PermissionDenied]: Excluding path due to permission denied: C:\...\locked\
```

The count pass runs inside `Log.StartIsolatingScope`, which stops messages from going further up. [`9eef035924dd7f78e169225d8d110b4315684f44`](https://github.com/duplicati/duplicati/commit/9eef035924dd7f78e169225d8d110b4315684f44) added the scope for that. [`5d6c612accd21b711d0db654822259192555513c`](https://github.com/duplicati/duplicati/commit/5d6c612accd21b711d0db654822259192555513c) (for #3305) changed it to `StartIsolatingScope(true)`, which detaches the scope right after creating it: the current scope goes back to the parent before `FileEnumerationProcess.RunAsync` is called, so the enumeration runs in the parent scope and nothing is isolated. The crash in #3305 was fixed by the same commit awaiting the tasks inside the scope.

## The change

`StartIsolatingScope(false)`, so the isolating scope is current for the enumeration it starts. The current scope is an `AsyncLocal`, so this does not reach the backup that called `CountFilesHandler.RunAsync`. The count itself does not log, and it still reports the file count and size.

## Checked

`CountFilesLogIsolationTests` (new) collects the "Including path" messages of a backup of 20 files:

| Test | Before | After |
|---|---|---|
| With the count pass (the default) | 2 messages per file, 3 out of 3 runs | 1 per file, 3 out of 3 runs |
| With `--disable-file-scanner=true` | 1 per file | 1 per file |

The first test also fails if the backup's own messages disappear, as it expects exactly one.

The command line on Windows, backing up a folder the user cannot list, with `--log-file`:

| | `PermissionDenied` warnings |
|---|---|
| Before, with the count pass | 2 |
| Before, `--disable-file-scanner=true` | 1 |
| After, with the count pass | 1 |
| After, `--disable-file-scanner=true` | 1 |

The exit code is still 2 (completed with warnings) after the change. `SymLinkTests`, `Issue6909`, `Issue6426`, `FolderStatusAccessFilterTests` and `FilterTest` (58 tests with the new ones) pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
