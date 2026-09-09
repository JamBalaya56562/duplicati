Fixes #4818

## What happens

On the command line, an option takes a value only after an equals sign. Written as `--restore-path D:\target`, the option has no value, and `D:\target` becomes one more path to restore. With no restore path, the restore goes to the original location, and the command line reports success, as the issue describes.

## The change

A restore stops with an error when `--restore-path` is given without a value:

```
ErrorID: RestorePathHasNoValue
The option --restore-path has no value. Write it as --restore-path=<folder>, or leave it out to restore to the original location.
```

The server only passes `restore-path` when it has a value, so restores from the UI are not affected.

## Checked

`RestorePathWithoutValueTests` (new) runs the command line as in the issue, after changing the file that was backed up:

| Test | Before | After |
|---|---|---|
| `restore <url> <file> --restore-path <folder>` | exit code 0, "Restored 1 (8 bytes) files to original location" | a non-zero exit code, the error message, nothing restored and the file left as it was |
| `restore <url> <file> --restore-path=<folder>` | restored into the folder | the same |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
