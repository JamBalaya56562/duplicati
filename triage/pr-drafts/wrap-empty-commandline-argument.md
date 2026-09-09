Fixes #3123

## What happens

`Utility.WrapCommandLineElement` returns an argument that is empty or only whitespace as it is, unquoted:

```csharp
if (string.IsNullOrWhiteSpace(arg))
    return arg;
```

An empty string adds nothing to a command line, and bare whitespace is read as the separator between arguments, so in both cases the argument disappears. Both callers are affected:

- **`Duplicati.WindowsService.exe install`** builds the service's image path with `WrapAsCommandLine` (`WindowsService/Program.cs:84` and `:134`). An empty argument on the install command line is missing from the registered command line.
- **Export as command line** (`Runner.GetCommandLine`, `RestAPI/Runner.cs:727`) writes every option as `--name=` followed by the wrapped value. A value that is only whitespace comes out as `--name= `, which reads back as `--name=` with the value gone.

This is the part of #3123 (the handling of `""` on the command line) that #7278 left open: that PR noted that an empty or whitespace-only argument still disappears, but did not change it.

## The change

- An empty argument is written as `""`.
- A whitespace-only argument no longer returns early. It goes through the normal path, which quotes it, because whitespace is outside `COMMANDLINE_SAFE`.
- A `null` argument is still returned as `null`.

The same applies to the Linux escaping, where `""` and `" "` are read back by the shell as an empty and a one-space argument.

## Red to green

`Duplicati/UnitTest/CommandLineWrappingTests.cs`, `[Category("Utility")]`, on Windows. Before the change: **13 red, 35 green**. After: **48 green**.

| Test | Before |
|---|---|
| `WrapCommandLineElementQuotesAnEmptyOrWhitespaceArgument`: `""`, `" "`, `"   "`, `"\t"` on Windows; `""`, `" "`, `"\t"` on Linux | 7 red: returned unquoted |
| `AWrappedWindowsArgumentIsReadBackAsItself`: the same four, read back with `CommandLineToArgvW` next to `--next=1` | 4 red: the argument is missing |
| `AWrappedWindowsCommandLineIsReadBackAsItsArguments`, now with an empty and a one-space argument in the service's command line | red: the empty and the one-space argument are missing |
| `AnOptionValueWrappedAfterTheEqualsSignIsReadBackAsItself`, the `--name=` + wrapped value shape of the export | `" "` red: read back as `--passphrase=`. `""` was already right in this position |
| `WrapCommandLineElementLeavesANullArgumentNull` | green before and after |

The Windows round trips use `CommandLineToArgvW`, which is how the service's arguments are read when it starts. For Linux, bash reads `""`, `" "` and `--passphrase=" "` back as an empty argument, a one-space argument and `--passphrase= ` (checked with `printf '<%s>\n'`).

## What changes for the callers

- **Export**: an option with an empty value is now written as `--name=""` instead of `--name=`. Both read back as the same empty value (`CommandLineToArgvW`, and bash), so the exported command does the same thing; the text is just more explicit. PowerShell was not checked; as noted in #7278, it reads quoting differently from both.
- **Windows service**: an empty argument now reaches the server as an empty argument instead of being dropped. The server's option parser (`FilterCollector.ExtractOptions`) only takes `--name=value` arguments, and the remaining arguments are only checked for a help string, so an empty one is ignored there, as it was when it was dropped.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
