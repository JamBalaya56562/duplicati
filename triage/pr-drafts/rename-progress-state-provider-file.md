## Summary

`Duplicati/WebserverCore/Services/LoginProvider copy.cs` only contains the `ProgressStateProviderService` class (the sole implementation of `IProgressStateProviderService`). The name looks like a leftover from an IDE "copy" in the WIP commit [32e852a392ee094a3f680e7a213000d8b6bc4b00](https://github.com/duplicati/duplicati/commit/32e852a392ee094a3f680e7a213000d8b6bc4b00), which makes the class hard to find by file name, and the space in the name broke the `for $(cat)` loop in `Localizations/duplicati/extract.sh`.

This PR renames the file to match the class. It is a pure rename: content, line endings and file mode are unchanged (same blob `99dfd0b6a1395598fae778ac338149758bc9022e`, mode `100644`).

Commit: [24589b7ee95514e6c0ee57362bd17b0d0ba67c61](https://github.com/JamBalaya56562/duplicati/commit/24589b7ee95514e6c0ee57362bd17b0d0ba67c61)

## Testing

- `git diff` shows only `rename from` / `rename to`, with no content hunks.
- `dotnet build Duplicati/WebserverCore/Duplicati.WebserverCore.csproj --no-incremental` succeeds, with the same warnings as on `master`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
