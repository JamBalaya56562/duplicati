Fixes #5720

# Label the rpm executables as binaries for SELinux

On distributions with SELinux in enforcing mode, the service installed by the rpm cannot connect to anything. The executables are installed below `/usr/lib/duplicati`, which the targeted policy labels `lib_t`. systemd starts the service through the `/usr/bin/duplicati-server` symlink, but the domain follows the label of the file it resolves to, so the service stays in `init_t` instead of moving to `unconfined_service_t`. `init_t` may not connect out, so every HTTPS connection is denied.

This adds the workaround from the issue to the rpm:

- `%post` adds a file context rule that labels `/usr/lib/<package>/duplicati` and `duplicati-*` as `bin_t`, and runs `restorecon` on the folder. Only the executables change label; the libraries stay `lib_t`.
- Without `semanage` (it is in `policycoreutils-python-utils`, which is not always installed), the label is set with `chcon` when SELinux is enabled. That label lasts until the whole system is relabelled. No new dependency is added.
- `%postun` removes the rule when the package is erased, not on upgrade.
- The commands are found with `command -v`, not `%{_sbindir}`: the packages are built on `fedora:latest`, where `/usr/sbin` is merged into `/usr/bin`, while `semanage` is in `/usr/sbin` on EL9.

The agent package uses the same template, so `/usr/lib/duplicati-agent` gets the same rule.

## Testing

On a Rocky Linux 9.8 VM (Hyper-V, SELinux enforcing, targeted policy) with the 2.4.1.0 CLI rpm. To test the template, I rebuilt that rpm from its own payload with the spec rendered from this branch, the way ReleaseBuilder renders it (release `stable.1`).

| | label of `duplicati-server` | domain of the service | AVC denials |
|---|---|---|---|
| 2.4.1.0 as released | `lib_t` | `init_t` | on start: `getsession` (twice) and `create` of the .NET debug pipe in `/tmp`; about 63 s later, when the server first connects out, 8 × `name_connect` to `http_port_t` (port 443) |
| upgrade from 2.4.1.0 to the rebuilt rpm | `bin_t` | `unconfined_service_t` | none in 60 s |
| fresh install without `semanage` (`chcon` path) | `bin_t` | `unconfined_service_t` | none in 60 s |
| fresh install with `semanage` | `bin_t` | `unconfined_service_t` | none in 60 s; in a 90 s run the server opened a connection to port 443 (`ss -tnp` showed it established), still with no denial |

After `dnf remove`, `semanage fcontext -l -C` no longer lists the rule. `Duplicati.Library.Main.dll` stays `lib_t` in every case.

I did not build the agent or GUI packages, and did not test on openSUSE, where `selinuxenabled` is absent and nothing runs.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
