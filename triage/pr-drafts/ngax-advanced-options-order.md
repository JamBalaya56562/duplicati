## Summary
Closes #2604.

In the old web UI (ngax), the list of advanced options is sorted, but each value was bound by its place in the unsorted list, so the labels showed the values of other options. #2975 bound each value by the option itself. Only the template changed, and no test checked it. This PR only adds a test.

## Testing
- New Playwright test `ngaxAdvancedOptionsOrder.spec.ts`. On the command line page it enters options that are not in alphabetical order as text, switches to the list, and checks that each label shows its own value. It then changes one value in the list and checks that only that option changed in the text. With the template binding by `$index` again, as before #2975, it fails: the values are shown next to the wrong labels. On master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
