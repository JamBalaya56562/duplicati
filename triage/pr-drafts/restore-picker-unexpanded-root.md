## What happens

In the old web UI (`ngax`), the restore file picker cannot check a root that has not been expanded. The checkbox stays empty and the console shows:

`TypeError: Cannot read properties of undefined (reading 'length') at $scope.toggleCheck (restoreFilePicker.js:208)`

When a node is checked, `toggleCheck` looks at the parent's children to see whether the parent is now fully selected. A root has no parent, so `p = findParent(node) || node` makes the node stand in for it, and a node's `children` are only loaded when it is expanded. The loop over `p.children` then reads the length of `undefined`.

A single root is expanded when the tree is shown (`if (roots.length == 1) $scope.toggleExpanded(roots[0])`), which hides this. With sources on more than one drive, there are several roots, and none of them can be checked until it is expanded.

## The change

The loop is skipped when `p` is the node itself. Its result is not used in that case: the next line already adds the node as it is when `p == node`. Nodes with a parent are unchanged.

## Red to green

There is no test framework for the `ngax` scripts, so this was checked by hand in a browser against a server built from this branch (`--webservice-webroot` pointing at the source tree):

1. A backup with the sources `Q:\srcA\` and `R:\srcB\` on two drives (made with `subst`, as in the issue).
2. Restore, and check `Q:\srcA\` before expanding it.

| | Before | After |
|---|---|---|
| Check an unexpanded root | **red**: the `TypeError` above, nothing selected | checked, the selection is `["Q:\srcA\"]`, no error |
| Check the second root, uncheck the first | (not reachable) | `["R:\srcB\"]` |
| Expanded root, and its children | works | works the same |
| Restore both roots, checked before expanding, to another folder | (not reachable) | `a.txt`, `sub\s.txt` and `b.txt` restored with their contents |

From reading its code, the new UI should not have this: its `toggleSelectedNode` works from the path strings and does not read `children`. It was not run for this.

Fixes #3483

🤖 Generated with [Claude Code](https://claude.com/claude-code)
