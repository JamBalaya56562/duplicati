## What happens

A remote synchronization destination whose `mode` is `interval` without an `interval`, or `counting`
without a `count`, synchronizes exactly once and is then never triggered again - silently.

`RemoteSynchronizationHandler` parses the configuration at
[RemoteSynchronizationHandler.cs:185-219](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/RemoteSynchronizationHandler.cs#L185-L219).
An interval that cannot be parsed is handled: `RemoteSyncInvalidInterval` is logged and the destination
runs inline ([:196-205](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/RemoteSynchronizationHandler.cs#L196-L205)).
A missing one is not: the destination is registered as `Interval` with `Interval = null` (or `Counting`
with `Count = null`). `ShouldTriggerSync`
([:385-395](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/RemoteSynchronizationHandler.cs#L385-L395),
[:418](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/Main/Operation/RemoteSynchronizationHandler.cs#L418))
then returns true the first time - nothing recorded yet - and afterwards evaluates
`(now - lastSyncTime) >= dest.Interval` or `backupCount >= dest.Count` against `null`, which a lifted
comparison makes `false` for ever.

### How a configuration gets there

- The server builds the JSON from `AdditionalTargetURLs` in
  [Runner.cs:1448-1501](https://github.com/duplicati/duplicati/blob/df30f7032e032850eca2da3b9e51ecc255dfb352/Duplicati/Library/RestAPI/Runner.cs#L1448-L1501):
  `mode` is always written, `interval` only when set, and `count` only when it is present in the entry's
  `Options` dictionary - there is no `Count` field on `ITargetUrlEntry`, so a `counting` entry set
  through the REST API or a configuration import lands here unless the caller thought of `Options["count"]`.
- The CLI takes the JSON by hand through `--remote-sync-json-config`, and its keys are not documented
  outside the source.
- The current web UI sends no `Mode`, so it gets the server default `inline` and is not affected.

## The change

The parser treats a missing interval or count the way it treats an unparsable interval: it logs
`RemoteSyncMissingInterval` / `RemoteSyncMissingCount` and runs the destination inline. Nothing else
changes; a destination that names its parameter behaves as before.

Two existing tests, `TestConfigure_Modes` and `TestConfigure_DefaultMode`, asserted the parsed mode of
an `interval` destination that had no interval - the configuration this PR stops accepting silently.
They now give it `"interval": "1h"`, which keeps what they test, the mode string.

## Red to green

`--filter "FullyQualifiedName~RemoteSynchronizationHandlerTests.TestConfigure_ModeWithoutItsParameter|FullyQualifiedName~RemoteSynchronizationHandlerTests.TestShouldTriggerSync_ModeWithoutItsParameter"`:
**4 failed** before, **4 passed** after, on Windows and on Linux (WSL). `TestCategory=RemoteSync` is green (44).

| Test | Before |
|---|---|
| `TestConfigure_ModeWithoutItsParameter_WarnsAndDefaultsToInline("interval", "RemoteSyncMissingInterval")` | fails: `Expected: Inline But was: Interval`, no warning |
| `TestConfigure_ModeWithoutItsParameter_WarnsAndDefaultsToInline("counting", "RemoteSyncMissingCount")` | fails: `Expected: Inline But was: Counting`, no warning |
| `TestShouldTriggerSync_ModeWithoutItsParameter_StillTriggersAfterAFirstSync("interval")` | fails: after one recorded sync `ShouldTriggerSync` is `false` - the "once and never again" above |
| `TestShouldTriggerSync_ModeWithoutItsParameter_StillTriggersAfterAFirstSync("counting")` | fails the same way |

The configuration tests capture the handler's log through a scope, so the warning is asserted, not
just the resulting mode.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
