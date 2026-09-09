On Windows, `EnvHelper.FindCommand` tries the value of the override variable (for example `NPM`) with each executable extension, `.exe` first. It threw "not found" as soon as the `.exe` did not exist. So `NPM=...\npm.cmd`, and `NPM=...\npm`, both failed for the npm of a Node.js install, which has `npm.cmd` and no `npm.exe`.

## The change

The value is now tried as given, and then with each extension. The first one that is executable is used. It is "not found" only when none of them exist, and "not executable" when only a file that cannot be run exists.

## Testing

There are no unit tests for ReleaseBuilder. I used a small console project that references ReleaseBuilder and calls `FindCommand("npm", "NPM")`:

| `NPM` | master | this branch |
|---|---|---|
| `...\npm.cmd` | `npm.exe` not found | `npm.cmd` |
| `...\npm` | `npm.exe` not found | `npm.cmd` |
| an existing `.exe`, or a path that does not exist | the same result on both | |

The master result is the same exception that a ReleaseBuilder run gave with `NPM` set.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
