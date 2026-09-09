Part of #6461. This fixes one of the places where "Stop now" left a backup running for ever. Stopping in the middle of a database statement or a source file read is not covered here.

## What happens

During a backup, the block splitter hands each block of a file to a block processor, then waits for the processor's answer before it goes on.

A processor that stopped between taking a block and answering for it never answered. The typical case is "Stop now" cancelling the database call the processor was making. The splitter then waited for ever. The backup waits for all its workers, so it never returned, and its local database stayed open.

A low `--cpu-intensity` makes this likely. With it, a processor pauses while it holds a block, and a stop that lands in the pause hits this.

Measured by stopping a backup of 200 new 256 KB files (4 KB blocks) while its blocks were being stored:

- Windows, default CPU intensity: stopped after 1.2 s and 2.4 s, neither backup had returned 60 s later. In a second run, the one stopped after 2.4 s hung again and the one stopped after 1.2 s returned. A heap dump of a hung run holds no backup worker any more, and the test could not delete the database file afterwards, as it was still open.
- Linux: with CPU intensity 10 and 1, stopped after 1.2, 2.4 and 4.8 s, 5 of the 6 had not returned 40 s later.
- Logging added for the probe showed the four processors leaving with `OperationCanceledException`, and four blocks never answered.

## The change

When the processor stops, it fails the answer for the block it holds. When that block was already answered, this does nothing. The splitter then gets the exception, and stops at its next check for a stop, as the other workers do.

The waiting side is not given a cancellation token. The backup waits for every worker anyway, so the processor itself has to end; once it answers, nothing is left waiting.

A processor that fails for another reason, such as a database error, also answers now, so the splitter is no longer left waiting in that case either. This is from reading the code, and it is not covered by a test.

## Checked

`AbortedBackupTests.AbortedBackupWhileBlocksAreStoredReturnsAsync` stops a backup 3 s after it starts, with `--cpu-intensity=1`, and expects it to return within 30 s:

| | Before | After |
|---|---|---|
| Windows | fails 3 of 3, still running after 30 s | passes 4 of 4, returns in about 4 s |
| Linux | fails 3 of 4, still running after 30 s | passes 4 of 4, returns in 3 to 4 s |

It depends on when the stop lands, so it can miss on the old code (1 of 4 on Linux). It does not fail on the new code.

`DisruptionTests` and `AbortedBackupTests` (39 tests) pass on Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
