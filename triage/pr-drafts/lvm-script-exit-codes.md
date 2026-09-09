## Summary
The LVM snapshot scripts check a command like this:

```bash
lvcreate ...
if [ "$?" -ne 0 ]
then
	EXIT_CODE=$?
	...
	exit $EXIT_CODE
fi
```

Inside the `then`, `$?` is the exit code of the test, which is 0. So after a failed `lvcreate`, `mkdir`, `mount`, `lvremove` or `rmdir`, the script printed its error and exited with 0. In `remove-lvm-snapshot.sh`, the retry of `umount` stored its exit code first, but then tested `$?` of that assignment, so a second failure went unnoticed and the script went on to `lvremove --force` the snapshot that was still mounted.

The exit code is now kept in `EXIT_CODE` before it is tested. A snapshot whose path cannot be found after creation exits with 255 instead of 0. `find-volume.sh` is not changed: its failures already end with a code other than 0.

Found while looking at #3249.

## Testing
- New tests in `LvmScriptExitCodeTests` run the scripts with stand-ins for the LVM tools on the path. They run on Linux only. In WSL (Ubuntu), on master:
  - `AFailedSnapshotCreationReportsTheExitCode` fails with `Expected: 5`, `But was: 0`.
  - `ASnapshotThatCannotBeUnmountedIsNotRemoved` fails: the second umount failure is not reported.
- With the change both pass.
- `bash -n` passes on both scripts. ShellCheck was not run locally.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
