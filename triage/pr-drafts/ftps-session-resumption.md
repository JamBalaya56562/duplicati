Title: Use Bouncy Castle when an FTPS server requires TLS session resumption

Fixes #4831
Fixes #6639

## What happens

FTPS servers can require each data connection to resume the TLS session of its control connection (RFC 4217):

- vsftpd with `require_ssl_reuse` answers `522 SSL connection failed: session reuse required`.
- FileZilla Server 1.x always requires it, and answers `425 Unable to build data connection: TLS session of data connection not resumed`.

.NET's `SslStream` gives no control over which session a connection resumes. `AllowTlsResume` can only turn resumption off ([dotnet/runtime#78305](https://github.com/dotnet/runtime/issues/78305)). In practice:

- With TLS 1.3, the session is not resumed on the data connection, so vsftpd refuses it even with one connection.
- With several connections to the same server (four uploads at a time by default), a data connection may resume the session of another control connection. FileZilla Server then refuses it, with TLS 1.3 and with TLS 1.2.

Duplicati drops the reply and reports only `Status is Failed`, and an empty file is left on the server.

## The change

[FluentFTP.BouncyCastle](https://www.nuget.org/packages/FluentFTP.BouncyCastle), from the FluentFTP project, is a custom stream that resumes the session of its own control connection, with TLS 1.2. It is MIT licensed and fully managed. Duplicati already ships `BouncyCastle.Cryptography` 2.7.0, through MimeKit and SSH.NET. FluentFTP.GnuTLS was the other candidate, but it is LGPL, needs native GnuTLS libraries, and does not list macOS.

The new `--ftp-tls-implementation` option (`--aftp-tls-implementation` for aftp) chooses the TLS implementation:

- `Auto` (default): the system TLS is used. When the server refuses a data connection for this reason (522, or 425 mentioning resumption), the client switches to Bouncy Castle and tries the list, upload or download once more. Some servers accept the transfer with 150 and then drop the data connection, so the pending reply is read then.
- `System`: the previous behaviour.
- `BouncyCastle`: used from the start.

`Auto` does not switch when `--ftp-ssl-protocols` excludes TLS 1.2. Bouncy Castle does not support client certificates.

A failed upload now includes the server's last reply in the error.

## Checked

Backups of 23 MB in 2 MB volumes, then `test all` with `--full-remote-verification`:

| Server | master | Auto | BouncyCastle | System |
|---|---|---|---|---|
| FileZilla Server 1.12.6, Windows | fails (TLS 1.3 and 1.2) | completes | completes | fails |
| FileZilla Server 1.12.6, Linux | fails | completes | | |
| vsftpd 3.0.5, `require_ssl_reuse` | fails | completes | completes | fails |

`test all` found no errors after each completed backup. With one upload at a time, master works against FileZilla Server, which matches the shared session explanation.

There are no unit tests for the FTP backend, so this was checked against the servers only.

BouncyCastle has no entry in `thirdparty/`; that is a separate PR.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
