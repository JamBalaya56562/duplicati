## What happens

In the restore file picker of the old web UI (`ngax`), unchecking a folder can leave some of its files selected, and restored.

When the last unchecked item in a folder is checked, `toggleCheck` selects the folder in place of its items, and moves up while every item of the next folder is selected too. For a folder with a parent, the next step of the loop removes the entries below the folder. When the loop reaches a root, there is no next step: the root is added, and the entries below it stay.

For example, with a root holding `sub/` and `a.txt`:

1. Check `a.txt`: the selection is `[a.txt]`.
2. Check `sub/`: every item of the root is now selected, so the root is added. The selection is `[a.txt, root/]`, and everything shows as checked.
3. Uncheck the root: only `root/` is removed. `a.txt` stays selected and checked, and the root shows as partly checked. A restore now restores `a.txt`, although the root was just unchecked.

## The change

When the loop selects a root, it removes the entries below it first, as the loop does for any other folder.

## Red to green

There is no test framework for the `ngax` scripts, so this was checked by hand in a browser (Chrome 152), clicking the checkboxes on the restore page of a backup with one root holding `sub/s.txt` and `a.txt`, against a server running the web root from this branch.

| Steps | Before | After |
|---|---|---|
| Check `a.txt`, check `sub/` | all checked, selection `[a.txt, root/]` | all checked, selection `[root/]` |
| Then uncheck the root | **red**: `a.txt` still checked, root partly checked, selection `[a.txt]` | all unchecked, selection `[]` |
| Check the root, uncheck `a.txt`, check it again | | `[root/]` |
| Expand `sub/`, check `s.txt`, check `a.txt`, uncheck the root | | `[sub/]`, then `[root/]`, then `[]`, all unchecked |

#7376, the fix for #3483 (a root that has not been expanded cannot be checked), is now in master and touches the same function, in separate lines. Checked again on today's master, with the server's web root switched between master and this branch:

- The first steps above, on master: the root ends partly checked with `a.txt` still checked, selection `[a.txt]`. With this branch: all unchecked, `[]`, and the other two rows give the results above.
- A backup with two roots (a local folder, and a folder under `\\wsl.localhost\...`), both not expanded. With this branch: checking the second root without expanding it selects it, with no error (#7376). Then, under the first root, checking `a.txt` and `sub/` gives `[second root/, first root/]`, unchecking the first root gives `[second root/]` with everything below it unchecked, and unchecking the second root gives `[]`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
