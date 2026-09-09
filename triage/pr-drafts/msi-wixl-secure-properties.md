wixl 0.106 ignores `Secure="yes"` on a `Property`, so the `SecureCustomProperties` list of the TrayIcon and Agent MSIs only has `PREVIOUSVERSIONSINSTALLED`, which wixl adds for the Upgrade table. The official 2.4.1.0 MSI has exactly that list.

The list matters when the installation is not privileged, for example an application that Group Policy assigns to a user: Windows Installer then passes only the listed public properties from the client to the server side ([SecureCustomProperties](https://learn.microsoft.com/en-us/windows/win32/msi/securecustomproperties), [Restricted Public Properties](https://learn.microsoft.com/en-us/windows/win32/msi/restricted-public-properties)). The sources mark the properties they need with `Secure="yes"` for this reason.

After the wixl build and the `InstallTables.sql` queries, ReleaseBuilder now writes the list from the sources: every `Property` with `Secure="yes"` and every `UpgradeVersion` property, the same list WiX writes (apart from the `BURNMSI*` properties WiX adds for Burn bundles). Upstream wixl does the same since [msitools d7035645](https://gitlab.gnome.org/GNOME/msitools/-/commit/d7035645f20587e7a3c0c2ca53d00de8b57833e8) (msitools#40), which is not in a release yet; with such a wixl, the queries write the same list again.

## Testing

- The list computed by the new `MsiSecureProperties` for the 2.4.1.0 TrayIcon sources has 18 properties, and for both packages it is the list WiX writes, apart from `BURNMSI*`.
- Applied to wixl builds of both packages, the queries change only the `SecureCustomProperties` row (all tables compared).
- The same queries applied to the official 2.4.1.0 MSI: it installs and uninstalls, both as an administrator and as a standard user.
- Not changed by this: an installation elevated through UAC. A standard user who installs the official MSI and accepts the UAC prompt with administrator credentials is privileged on the client side (`Privileged=1`), so `INSTALL_TLS_CERTS` reached the server side with both the official MSI and this one (checked in the logs). The effect is only for installations that are not privileged, which was not tested.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
