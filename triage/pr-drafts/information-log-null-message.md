## What happens

`Log.WriteInformationMessage(tag, id, message, params arguments)` has no exception argument, unlike `WriteWarningMessage` and `WriteErrorMessage`. Seven calls passed `null` where the exception would go:

```csharp
Log.WriteInformationMessage(LOGTAG, "SecretProviderFailedToGetEncryptionKey", null, Strings.Program.SecretProviderFailedToGetEncryptionKey);
```

So `null` became the message and the text became a format argument. `LogEntry.FormattedMessage` then fails on `string.Format(null, ...)` and falls back to its error text. The server logs one of these at every start:

```
[Information-Duplicati.Server.Program-SecretProviderFailedToGetEncryptionKey]: Error while formating: "" with arguments: [Failed to get encryption key from secret provider]
```

## The change

The `null` is removed from the seven calls:

- `Server/Program.cs`: `SecretProviderFailedToGetEncryptionKey`, `WindowsLogMissingCreating`
- `RestoreHandler.cs`: `NoFilesNeededRestore` (twice)
- `CompactHandler.cs`: `SkipDeleteLockedRemoteVolume`, `SkipCompactLockedRemoteVolume`
- `RepairHandler.cs`: `RecoverySuggestion`

The many `WriteVerboseMessage` and `WriteExplicitMessage` calls that pass `null` in the same place are not affected: those methods have an overload with an exception, which the call binds to.

## Red to green

`Duplicati/UnitTest/InformationLogMessageTests.cs` (new) backs up a file, restores it to where it already is, and checks the logged `NoFilesNeededRestore` message.

| | Before | After |
|---|---|---|
| `RestoreWithNothingToDoLogsItsMessageAsync` | **red**: `Error while formating: "" with arguments: [Restore completed ...` | green |

The server log at start, with `--log-level=Information`:

- Before: `Error while formating: "" with arguments: [Failed to get encryption key from secret provider]`
- After: `Failed to get encryption key from secret provider`

Measured on Windows. The change is not platform specific, and the Linux run could not be made (the WSL VM did not start).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
