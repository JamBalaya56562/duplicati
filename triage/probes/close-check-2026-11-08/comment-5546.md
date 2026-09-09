I think this was fixed by the SSH.NET update in 2.1.0.3 (beta) and 2.1.0.4 (stable). Those releases moved from SSH.NET 2023.0.1, the version in 2.0.8.1, to 2024.2.0.

I reproduced the setup on Windows 11. An SSH server listened on `127.0.0.1` only, and `localhost` resolved to `::1` first, then `127.0.0.1`. A plain TCP connection to `::1` was refused, as with the missing IPv6 port sharing here.

- SSH.NET 2023.0.1 failed to connect to `localhost` with "connection refused". It connected to `127.0.0.1`.
- SSH.NET 2024.2.0, 2025.1.0 and 2026.0.0 all connected to `localhost`.
- On current master (SSH.NET 2026.0.0, as in 2.4.1.0), `Duplicati.CommandLine.BackendTool.exe list "ssh://localhost:<port>/..."` listed the folder.

If nobody can still reproduce this on 2.1.0.4 or later, I think it can be closed.
