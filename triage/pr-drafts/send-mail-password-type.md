## Summary
Closes #3027.

The mail password was shown in plain text in the advanced options. The option editors hide an option only when it is declared as a password, and https://github.com/duplicati/duplicati/commit/ca829acb3126d28e2d0472fe7368ab91e3ec98a9 declared `send-mail-password` that way, without a test. This PR only adds a test. As noted in the issue, "Edit as text" still shows the value, which is by design.

## Testing
- New test `SendMailPasswordOptionTests.TheMailPasswordIsDeclaredAsAPassword`. With the option declared as `String` again it fails: `Expected: Password`, `But was: String`. On master it passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
