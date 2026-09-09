## What happens

`RestoreTestHandlerTests.CorruptedDblockIsReportedWithPathsAndErrorExitCodeAsync` fails now and then with

```
The damaged volume should hold data for at least one file
Assert.That(condition, Is.True)
```

Seen on `Unit tests (macos-latest)` in four of eleven pull requests that do not touch the restore test (#7326, #7336, #7343, #7345); the same test passed on the other seven and on #7339 and #7348.

### Why

The test damages the first dblock by name:

```csharp
var dblocks = Directory.GetFiles(TARGETFOLDER, "*.dblock*").OrderBy(x => x).ToList();
var corrupted = dblocks[0];
```

Block volumes are named `duplicati-b<guid>.dblock.zip.aes` ([VolumeBase.cs:210](https://github.com/duplicati/duplicati/blob/34f6c753a20e/Duplicati/Library/Main/Volumes/VolumeBase.cs#L210)), and the guid is random, so "first by name" is a different volume on every run. The backup in this test (12 files of 1-60 KB, `blocksize` 10 KB, `dblock-size` 100 KB) writes four or five volumes, and the last one is sometimes a small volume holding only blocklist and metadata blocks. `GetFilesInVolumeAsync` walks `File -> BlocksetEntry -> Block`, so for that volume it returns no paths, and when the random name sorts it first the assertion fails.

Measured on Windows with a throwaway test that runs the same backup 100 times and inspects every volume in the database: 17 of the 486 volumes held no file data (1-3 blocks, 0.8-1.5 KB: blocklist only 9, blocklist and metadata 5, metadata only 3), and 6 of those sorted first. That is a 6 % failure rate for this test on Windows too; macOS just hits it more often.

## The change

The test picks the volume to damage from the database instead of from the name order: the first dblock for which `GetFilesInVolumeAsync` returns at least one path. The rest of the test is unchanged and its assertions still hold (`affected.Count < files.Count`, every file in the volume fails with `MissingRemoteVolume` naming that volume).

The small trailing volume itself is fine; only the test's assumption that any volume holds file data was wrong.

## Red to green

`RestoreTestHandlerTests` on Windows: 16 of 16 green. A longer repeat cannot be run yet: the restore of a corrupted volume deadlocks now and then (unrelated to this change; the unmodified test hangs the same way), so a repeated run stops before it finishes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
