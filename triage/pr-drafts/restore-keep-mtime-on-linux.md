## Summary

On Linux, a restored file or folder whose last write time was later than its status change time (for example a file with a timestamp in the future) did not get its last write time back. It got the time of the backup instead.

The restore sets the last write time and then the creation time. Linux cannot set a creation time, and .NET's `File.SetCreationTimeUtc` / `Directory.SetCreationTimeUtc` set the last write time instead on every Unix except macOS ([`FileStatus.SetTimes.OtherUnix.cs`](https://github.com/dotnet/runtime/blob/release/10.0/src/libraries/System.Private.CoreLib/src/System/IO/FileStatus.SetTimes.OtherUnix.cs)). So the second call overwrote the first. On Linux, .NET reports the creation time as the earlier of the change time and the last write time. For most files that is the last write time, so nothing visible happened. When the last write time is later than the change time, the stored "creation time" is the change time, and that is what the restored entry ended up with.

`SystemIOLinux.FileSetCreationTimeUtc` and `DirectorySetCreationTimeUtc` now only set the creation time on macOS, which can store it. These are only called by the restore.

## Testing

New `RestoreLastWriteTimeTests.RestoredEntriesKeepTheirLastWriteTimeAsync` restores a file and its folder with a last write time either in 2099 (later than the change time) or in 2001 (earlier), with both restore engines.

- Linux (WSL, .NET 10, ext4), without the fix: the 2099 cases fail for both engines, e.g. `Expected: 2099-01-02 03:04:05` / `But was: 2026-10-22 01:13:27.9458157`, for both the file and the folder. The 2001 cases pass.
- With the fix: `RestoreLastWriteTimeTests`, `RestoreHandlerTests`, `ProblematicPathTests`, `SymLinkTests`, `RestoreSymlinkMetadataTests` and `Issue6068` (several of these compare the restored times with the source, including the creation time) pass, 70 of 70.
- Windows: builds with no warnings in the touched files, and the new test passes there (4 of 4); the Windows code path is unchanged.
- macOS: not run. The code path there is unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
