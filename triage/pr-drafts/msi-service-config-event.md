Title: Set the MSI service config again on a repair

A repair with the MSI did not set the service config (start delayed) again.

## The change

- The `MsiServiceConfig` rows of the TrayIcon and Agent services used Event 3, described as install (1) and reinstall (2). In the table, 2 is uninstall and 4 is reinstall, so 3 is install and uninstall. That is why the uninstall still got a `ServiceConfigure` op after f58900bcd55cb510b4ac2f53b0142ec696d0886a changed the value from 7, which the `NOT REMOVE~="ALL"` condition then had to skip. Event 5 (install and reinstall) is what WiX writes for `OnInstall="yes" OnReinstall="yes"`. The condition is kept as a guard.
- A repair still skipped the service component. `Duplicati.WindowsService.exe` is written by hand in `Duplicati.wxs`, not by the harvester, so it had no `DefaultVersion`. wixl leaves the File version empty, and the installed file, which has a version, counts as newer ("higher versioned keyfile exists"). It now gets the product version, as the harvested files do since 8afeadf55b278ccfcf7fc9e1ea815f16cfcecd80.

## Testing

On Windows 11 with an MSI built by wixl from this branch (product version 2.0.0.99, like a release where the product and file versions match): install with the service, set DelayedAutostart to 0, repair. Before, it stayed 0 and the log showed the service component with `Action: Null`. With the change, it is 1 again, and the component is reinstalled (`Action: Local`). The uninstall works.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
