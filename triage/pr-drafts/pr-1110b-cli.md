The second argument of the `test` command is the number of samples. The Commandline page of the UI fills the arguments with the backup sources, so `test` got a folder there and crashed with a `FormatException` from `Convert.ToInt64` (exit code 100).

## The change

The `test` command now says that the sample count must be a number or "all", shows the value it got, and exits with code 200, the same as for a wrong number of arguments:

```
The number of samples to test must be a number, or "all", but was: C:\Users\Jam\Documents
```

The UI no longer puts the sources into the arguments of other commands since duplicati/ngclient#662. This change covers any other way a wrong value reaches the command.

## Testing

New `CommandLineTestSampleCountTests` (3 tests). On master, 1 of them fails (exit code 100, `FormatException`). On this branch, all 3 pass. The real CLI also prints the message above and exits with 200.

Run again after rebasing onto master [c16a28aa8](https://github.com/duplicati/duplicati/commit/c16a28aa8cfb8564fa23b9caa5499b33711aae80), in one build with the other branches I am opening today: 48 tests passed, among them the 3 tests above. No new warnings in the changed files.

Refs #4082

🤖 Generated with [Claude Code](https://claude.com/claude-code)
