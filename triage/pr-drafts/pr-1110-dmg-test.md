The DMG installer tests failed twice on macOS, right after `CreateDmg`, in the `File.OpenRead` of `MakeJob`:

```
System.IO.IOException : The process cannot access the file '.../update.dmg' because it is being used by another process.
```

- `DmgInstallerSwapsTheBundleAndRollsBack`, line 927 ([run](https://github.com/duplicati/duplicati/actions/runs/42581998079/job/129042700453))
- `DmgInstallerRefusesAnImageForAnotherInstallation`, line 962 ([run](https://github.com/duplicati/duplicati/actions/runs/42587268544/job/129059964039))

On Unix, .NET takes a shared `flock` with `LOCK_NB` to read a file, and reports `EWOULDBLOCK` this way (`SafeFileHandle.Unix.cs` in release/10.0). So something still held the image locked after `hdiutil create` had exited. I could not find out what, as I have no Mac.

## The change

`CreateDmg` waits, for up to a minute, until the image can be opened for reading. Each wait is written to the test output. The installer and what the tests check are unchanged. The installer is given a downloaded package, not one that `hdiutil` has just written, so this only affects the test setup.

## Testing

- The wait was tried on Windows with a scratch test. While another handle held the file with `FileShare.None`, the wait went on. When the handle was released after 1.5 s, it returned after 1546 ms. A timeout throws the `IOException`.
- `UpdateInstallTests`: 33 passed, and the 2 DMG tests are skipped on Windows. No warnings in the changed file.
- Not tried on macOS.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
