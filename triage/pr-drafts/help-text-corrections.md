## Summary

Six help texts that do not match what the code does:

- **`help aes`, `--aes-version`**: the help reports `default value: 3` (the SharpAESCrypt default), but since [73a3e627c1eb9dc791c1a4cf3a72f71f60f86d71](https://github.com/duplicati/duplicati/commit/73a3e627c1eb9dc791c1a4cf3a72f71f60f86d71) (#6889) Duplicati writes version 2 unless the option is set. The default and the help now come from one `DEFAULT_AES_VERSION` constant, so switching to v3 later is a one-line change that updates the help too. Behaviour is unchanged.
- **`--webservice-pre-auth-tokens`**: the help says the header is `Authentication: PreAuth <token>`; `PreAuthTokenHandler` reads `Authorization`.
- **RecoveryTool help**: it pointed to `help backends`, which is not a topic of the command line client. It now points to `help` (the "Targets" line) and `help <backend>`.
- **SMB `--auth-domain`**: the help said the domain can be supplied as the `AUTH_DOMAIN` environment variable, but nothing reads that variable (only `AUTH_USERNAME` / `AUTH_PASSWORD` are mapped). The sentence is removed.
- **SMB buffer size options**: "values bellow 10000 bytes" → "below".
- **`--snapshot-provider`**: the description still said Vanara is the default and works on every architecture, and that only AlphaVSS needs the VC++ Redist. Since [4941a13ed1871783eb538fdc5fddedd3e3a217f1](https://github.com/duplicati/duplicati/commit/4941a13ed1871783eb538fdc5fddedd3e3a217f1) ("Add native VSS provider") the default is `Native` (`WindowsSnapshot.DEFAULT_WINDOWS_SNAPSHOT_PROVIDER`). `VCREDIST_PROVIDERS` lists both AlphaVSS and Vanara, and on ARM only Native and WMI are offered (`SUPPORTED_PROVIDERS`). The description now says that, and describes WMI as creating the snapshot without asking the writers to flush (the comment on `WindowsSnapshotProvider.Wmi`). The `default value` line already showed `Native`, so only the description changes.

## Testing

Built on Windows (.NET 10) and compared the output before and after the change:

- `Duplicati.CommandLine.exe help aes`: `* default value: 3` → `* default value: 2`. A backup made with this build still writes `AES\x02` headers to every volume.
- `Duplicati.CommandLine.exe help smb`: the `AUTH_DOMAIN` sentence is gone, and both buffer size options say "below".
- `Duplicati.CommandLine.RecoveryTool.exe help`: the line now reads ``Use `Duplicati.CommandLine.exe help` to see the supported backends (listed as "Targets"), and `Duplicati.CommandLine.exe help <backend>` to see the options for a backend.`` Both targets exist (`help` prints the `Targets:` line, and `help s3` prints the S3 options).
- `Duplicati.Server --help`: `--webservice-pre-auth-tokens` ends with `Authorization: PreAuth <token>`.
- `Duplicati.CommandLine.exe help snapshot-provider`: the description now starts with "The Native provider is the default", and the value line still reads `* default value: Native`. On Windows this topic currently throws a `FormatException` because of the `--vss-provider-id` description, which is fixed separately in #7481. That fix was applied locally while the output was captured, and is not part of this branch.
- No new build warnings in the Encryption, SMB, RestAPI and Main projects.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
