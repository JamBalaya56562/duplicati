`Dispose` of the Windows, Linux and macOS raw disks freed the aligned buffer, closed the device and disposed the I/O lock without taking the lock. A read that was still copying out of the buffer then read freed memory. On Linux and macOS, a closed file descriptor number can also be given to another file.

A disk is disposed with its source provider, and a listing that the backup no longer waits for can still be reading it. The Windows unit tests crashed twice with an `AccessViolationException` in `Disk.Windows.ReadBytesAsync`, below `PartitionSourceEntry.Enumerate` ([10-30](https://github.com/duplicati/duplicati/actions/runs/41145202038/job/124368564061), [11-09](https://github.com/duplicati/duplicati/actions/runs/42587254531/job/129059918640)). #7760 stops the backup from leaving that listing behind when it ends normally. An aborted backup still leaves its listings behind, so that a stuck source cannot hold it up (#7520).

## The change

- `Dispose` takes the I/O lock, and waits up to 30 seconds for a read or write that is still running.
- A read or write that gets the lock after the disk was disposed throws `ObjectDisposedException`.
- The lock is no longer disposed, so a read or write that is waiting for it is not left waiting for ever.
- If the running read does not end in time, its buffer is left allocated instead of being freed under it.

## Testing

New `Test_RawDisk_DisposeWhileReading_DoesNotCrash_Async` in `DiskImageUnitTests`: 4 readers read 8 MiB at a time from the GPT test disk while it is disposed. Every read must either complete or stop with an exception, and all readers must end.

Not run locally: the `DiskImageUnit` tests need administrator rights to attach the test disks, and I could only build. The Windows job of this PR runs it. Before this change, the test would only fail by chance, and then the test process crashes, as in the CI runs above.

Builds with no warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
