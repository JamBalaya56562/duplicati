Title: Fail the ShellCheck job on warnings too

## Summary
The ShellCheck job added for #2736 failed only on errors, because the scripts still had warnings. #<lvm PR> and #<shellcheck-warnings PR> fixed them, so warnings now fail the job as well. Style notes are still not checked.

`remove-lvm-snapshot.sh` set `NAME` and `DEVICE` from its arguments but never used them. Its header comment already describes the arguments, so the two assignments are removed.

## Testing
- ShellCheck 0.11.0 with `--severity=warning` reports nothing for the tracked `.sh` files on this branch. On master it reports 55 warnings.
- The ShellCheck workflow passed on the fork ([run 44980691379](https://github.com/JamBalaya56562/duplicati/actions/runs/44980691379)).
- `NAME` and `DEVICE` are not referenced anywhere else in the script.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
