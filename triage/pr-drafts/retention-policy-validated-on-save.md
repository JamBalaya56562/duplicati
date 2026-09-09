Fixes #7425

## What happens

When a backup is saved, the server checks `keep-versions` and `keep-time` (`Connection.ValidateBackup`), but not `retention-policy`. A value the backup cannot use is saved without a word, and every run of the backup then fails before it starts:

- `2W:U,2M:60D,4M:16W,2Y:48M;` (the trailing `;` from the issue) fails with `Unparsed data: ;`
- `2W:U,2M:60D,4M:16W,2Y:48M` (an interval of 48 months in a timeframe of 2 years) fails with "An error occoured while processing the value of --retention-policy"

At run time the messages do not help either:

- `Controller.ValidateOptions` first reads the value outside the check that wraps it, to see which retention options are set. A value that does not parse fails there, with the bare parser message, which does not name the option.
- When the check does catch the error, its message leaves out the cause, so the interval error above shows only the outer message.

## The change

- **Saving:** `Connection.ValidateBackup` also parses `retention-policy` and checks that no interval is bigger than its timeframe. A backup with a value that fails is rejected with `The value of retention-policy is not valid: <cause>`. This covers creating, updating and importing a backup.
- **Same rules:** the parsing and the interval check move from the `RetentionPolicy` getter and `Controller.ValidateOptions` into two static methods of `Options` (`ParseRetentionPolicy`, `ValidateRetentionPolicy`), used by both the server and the run.
- **Running:** the value is read inside the check, and the message is `An error occoured while processing the value of --retention-policy: <cause>`.

## Checked

`ServerApiIntegrationTests.SavingABackupWithAnInvalidRetentionPolicyIsRejected_Async` (new) saves a backup through `POST /api/v1/backups`, and changes an existing one through `PUT /api/v1/backup/{id}`, with each of the two values above:

| | Before | After |
|---|---|---|
| trailing `;` | fails: `got 200: {"ID":"1","Temporary":false}`, the backup is saved | passes: 400, the error names `retention-policy`, and a rejected update leaves the stored value alone |
| interval bigger than its timeframe | fails: `got 200` | passes |

`RetentionPolicyValidationTests.ABackupWithAnInvalidRetentionPolicyNamesTheOptionAndTheCause` (new) runs a backup with each value:

| | Before | After |
|---|---|---|
| trailing `;` | fails: a plain `System.Exception` with the parser message, not a `UserInformationException` naming the option | passes |
| interval bigger than its timeframe | fails: the message does not contain the cause | passes |

The existing `DeleteHandlerTests`, which use the `RetentionPolicy` getter, pass. The build reports no warnings in the files this changes.

I have not checked how the UIs show the rejected save.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
