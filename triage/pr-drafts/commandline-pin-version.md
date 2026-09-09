Fixes #4159

## What happens

A command sent from the web interface's command line page is not run right away. `CommandlineRunService.StartTask` puts it in the task queue with its arguments as they are, and it runs when its turn comes.

`--version` names a backup version by its place in the list, newest first. When a backup runs before the queued command (the scheduled backup in #4159, or one that was already running when the command was sent), it adds a version at the front and every number moves up by one. The command then acts on the version next to the one the user named. For `delete --version=1` that removes the wrong backup version.

## The change

`CommandlineVersionPinning` (new, in `WebserverCore/Services`) pins the versions when the command is sent and puts them back when it runs:

- **When the command is sent**, if it has a `--version` and a `--dbpath` (the command line page always sends both), the numbers are read the same way the operations read them (`Options.Version`, so lists and ranges work) and turned into the versions' times from the `Fileset` table.
- **When the command runs**, the times are turned back into the current numbers and the `--version` argument is rewritten. With nothing in between, the numbers come out the same.
- If a named version **no longer exists** when the command runs (deleted in the meantime, for instance by retention), the command is **not run** and reports why, rather than being run on the version that took the number. The same applies if the versions could not be read when the command was sent.

The database is read with a read-only connection of its own, not through the operations' database lock. The command may be sent while a backup is writing to that database, and waiting for the lock would read the list after the backup, with the numbers already moved.

A number that names no version when the command is sent is left alone, so the command reports it as it did before.

## Red to green

`Duplicati/UnitTest/CommandlineVersionPinningTests.cs` (new). Each test makes real backups, sends the command through `CommandlineRunService.StartTask` into a queue that holds it, and runs the queued task when the test says so, the way the queue runner runs a custom task. The version list is read back with `ListFilesetsAsync`.

| Test | Before | After |
|---|---|---|
| A `delete --version=1`, with a backup run before the queued command | **red**: the version that was number 1 when it was sent is still there, and another one is gone | green |
| A `delete --version=0-1`, with a backup run before the queued command | **red**: a version named by the range is still there | green |
| A `delete --version=1` whose version is deleted by something else before the command runs | **red**: no error, the command ran instead of stopping | green: `CommandlineVersionNoLongerExists`, nothing deleted |
| A `delete --version=1` with nothing in between | green | green |

Before the change: 3 red, 1 green. After: 4 green. No warnings in the changed files.

## Not covered

- **Without `--dbpath`**, for instance a command sent to the API by hand that relies on the database being found from the storage URL, the versions are not pinned and the command runs as before. The command line page always sends `--dbpath`.
- **`compare`** takes its two version numbers as positional arguments, not `--version`, so they are not pinned. It only reads.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
