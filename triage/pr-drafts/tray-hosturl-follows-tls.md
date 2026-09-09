Title: Keep the tray icon host URL in step with TLS on an upgrade or a change

With the service installed, the tray icon connects to `http://127.0.0.1:8200` unless the installer stored another host URL in `duplicati-trayicon-hosturl`. `StoreTrayIconValues` stores `https://127.0.0.1:8200` there, but only when the service is installed for the first time. So:

- Turning on "Generate and use TLS (HTTPS) certificates" in an upgrade (or with Change) switches the service to HTTPS, but the tray icon keeps using HTTP and cannot connect. This is what #7804 describes.
- Turning TLS off with Change switches the service to HTTP, but the tray icon keeps the stored HTTPS URL and cannot connect.

## The change

When the service was installed before and stays installed, a new client-side action after `ExecuteAction`, `SyncTrayIconHostUrl`, stores the host URL with `SecretTool`, as `StoreTrayIconValues` does:

- `https://127.0.0.1:8200` when the TLS feature is being installed,
- `http://127.0.0.1:8200` when it is being removed, or when an upgrade leaves it out.

A plain repair stores nothing, so a host URL entered in the tray icon is kept. The first install of the service is unchanged (`StoreTrayIconValues`). Like that action, this runs in the UI sequence, so a silent install (`/qn`) does not update the URL.

## Testing

On Windows 11, with the official 2.4.0.1 and 2.4.1.0 MSIs, and a copy of the 2.4.1.0 MSI with only this change added (the script as a Binary, the three custom actions and the three InstallUISequence rows, with the same conditions, set with `msilib`). The tray icon was started from the Start menu shortcut after each step.

| Step | Official 2.4.1.0 | With this change |
|---|---|---|
| 2.4.0.1 with the service, no TLS | HTTP; no URL stored; tray icon connects | same |
| Upgrade to 2.4.1.0 with TLS checked | HTTPS; no URL stored; tray icon does not connect | HTTPS; `https://127.0.0.1:8200` stored; tray icon connects |
| Fresh 2.4.1.0 with the service and TLS | HTTPS; `https://127.0.0.1:8200`; connects | same, the new actions are skipped |
| Change with TLS unchecked | HTTP; still `https://127.0.0.1:8200`; does not connect | HTTP; `http://127.0.0.1:8200` stored; connects |

The install logs show `SetTrayIconHostUrlHttps` then `SyncTrayIconHostUrl` in the upgrade, `SetTrayIconHostUrlHttp` then `SyncTrayIconHostUrl` in the change, and all three skipped in the fresh install.

I did not build the MSI from this branch, and I did not try a repair with a host URL entered in the tray icon.

Fixes #7804

🤖 Generated with [Claude Code](https://claude.com/claude-code)
