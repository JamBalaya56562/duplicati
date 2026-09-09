## What happens

After each test, the cleanup in `BasicSetupHelper` deletes the test folders with a recursive `Directory.Delete`. On Windows, this fails when there is a junction anywhere below the folder:

1. When the delete reaches the junction, it first tries to unmount it with `DeleteVolumeMountPoint`. That call is refused with access denied.
2. The junction itself is still removed.
3. The delete then throws `UnauthorizedAccessException`. The test fails in its teardown, and the rest of the folder is left for the next test.

I measured this with .NET 10.0.12. The result is the same with and without the `\\?\` prefix, and what the junction points to is not touched.

Removing the folder links first, one at a time with a non-recursive delete, lets the recursive delete succeed.

## The change

On Windows, the cleanup now removes the folder links below each test folder before it deletes the data, target and restore folders. On other systems it deletes them as before. Only test code changes.

## Checked

`TestFolderCleanupTests` puts a junction two levels down in the data folder and calls the cleanup:

- **Before:** the cleanup throws `UnauthorizedAccessException`.
- **After:** the data folder is removed, and the folder the junction points to is left alone.

`SymLinkTests`, `NestedSourceExclusionTests` and `AlternateDataStreamTests` also pass through the changed cleanup: 25 tests in total, on Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
