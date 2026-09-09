The unit test project on master does not build:

```
RepairHandlerTests.cs(803,38): error CS7036: There is no argument given that corresponds to the required parameter 'collectDatabaseMessages' of 'BackendManager.BackendManager(string, Options, IBackendWriter, ITaskReader, bool)'
```

`AbortedRepairDoesNotSetTheDatabaseAsideAsync`, added in #7382, creates a `BackendManager` with four arguments. [`eb148ec6`](https://github.com/duplicati/duplicati/commit/eb148ec6b68b71275c7d98851b06daf28cb8a73a) ("Avoid storing sync ops in memory") added the required `collectDatabaseMessages` parameter, and the two were merged on the same day, so each built on its own.

## The change

The test passes `collectDatabaseMessages: true`, as the `Controller` does for every operation but sync. The test runs a repair, so this keeps it the same as a repair started through the `Controller`.

## Checked

On master [`bb659c33`](https://github.com/duplicati/duplicati/commit/bb659c33ad0a0c0fbab65fe8c28a8364d25f6b35), Windows: the unit test project builds again with no warning in `RepairHandlerTests.cs`, and all of `RepairHandlerTests` pass (23).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
