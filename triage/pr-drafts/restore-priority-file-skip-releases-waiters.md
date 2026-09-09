Builds on #7364 and the branches after it (`fix/restore-skipped-file-releases-blocks`, `fix/restore-report-empty-file-failure`), as it changes the same handlers. Open it after those are merged, rebased on master.

## What happens

Files other than the priority files wait until every priority file has been restored, or until a priority file fails and faults the priority barrier (`FaultPriorityBarrierIfPriorityFile`). Two of the ways a file is given up do neither:

- an empty file that cannot be created;
- a file with blocks in no volume (negative volume ID).

When such a file is a priority file, the other files wait until the restore is aborted. With one file processor, none of them is restored.

The file restore destination has no priority files of its own. A restore callback module can add some (`OnPreparePriorityFilesAsync`), which is how the tests below make one.

## The change

Both paths fault the barrier, as the other ways of giving up a file do. What happens after that is unchanged: the files waiting for the barrier fail the restore with the priority file's error.

## Red to green

Two tests in `RestoreFileFailureTests`, with a callback module that makes one file a priority file. Each checks that the restore ends within two minutes, whether or not it succeeds, and that the module did mark the file.

| Test | Before | After |
|---|---|---|
| The empty priority file cannot be created (a folder is in the way) | **red**: still running after two minutes | green: ends in seconds |
| The priority file has its blocks in no volume | **red**: still running after two minutes | green |

Measured on Windows and on Linux (ext4, WSL) with the same results. Before the change, each red test has to run on its own: the aborted restore it leaves behind can break the next test's backup. The class (9 tests) and the related restore tests (19) pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
