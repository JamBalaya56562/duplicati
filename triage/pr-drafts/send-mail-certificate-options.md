Fixes #4552

The mail report has no options for the certificate of the mail server. [`92d6d666ee89`](https://github.com/duplicati/duplicati/commit/92d6d666ee89e1e08ede98b21bb6fc4eab36687f) gave the HTTP report options to accept any certificate, certificates with given hashes, and certificates whose revocation status cannot be checked, all through `SslCertificateValidator`, but `SendMail` creates the MailKit `SmtpClient` and connects without a validation callback, so MailKit keeps validating the certificate on its own.

On [the forum](https://forum.duplicati.com/t/20747), mail reports fail on several Macs, with servers using a Let's Encrypt certificate:

```
Failed to send message: MailKit.Security.SslHandshakeException: The server's SSL certificate could not be validated for the following reasons:
• An incomplete certificate revocation check occurred.
```

The users tried `--ignore-revocation-failure` (2.3.1.0) and saw no change. That option is read by the backends, not by the report modules, and the HTTP report has its own `--send-http-ignore-revocation-failure`.

This adds the same three options to the mail report:

- `--send-mail-accept-any-ssl-certificate`
- `--send-mail-accept-specified-ssl-hash`
- `--send-mail-ignore-revocation-failure`

When any of them is set, the `SmtpClient` gets `SslCertificateValidator.ValidateServerCertificate` as its validation callback, and `CheckCertificateRevocation` is turned off, as the validator fetches the revocation status itself when it needs it. Without them, nothing changes: MailKit validates the certificate as before, so the default stays as strict as it is now.

#4552 asks for a better way to handle mail server certificates than accepting any certificate. With these options, a user can accept a known certificate by its hash, or only tolerate a failed revocation check, and the default stays strict.

The help texts are the ones of the HTTP report, with the option name of the mail report in "Please use --{0} instead".

## Testing

New `SendMailCertificateOptionsTests`. They run a minimal SMTP server over TLS (`smtps://`) with a self-signed certificate on the loopback interface, send a report for a failed backup through `SendMail`, and check whether the server got the message:

| test | master | with the change |
|---|---|---|
| `AnUntrustedCertificateIsRefusedByDefaultAsync` | refused | refused |
| `AnyCertificateIsAcceptedWhenAskedForAsync` | refused (the option was not known) | delivered |
| `ACertificateWithAGivenHashIsAcceptedAsync` (and the hash of another certificate) | refused | delivered (refused with the other hash) |

The revocation failure was reproduced on Linux with a separate probe, which is not part of this PR because it needs a CA that the process trusts from its start (`SSL_CERT_DIR`). A private CA signs a server certificate whose CRL and OCSP addresses cannot be reached. `X509Chain` then reports only `RevocationStatusUnknown` and `OfflineRevocation` when it checks online, and a valid chain with `NoCheck`.

| options, through `SendMail` | master | with the change |
|---|---|---|
| none | refused | refused |
| `--ignore-revocation-failure` | not run | refused |
| `--send-mail-ignore-revocation-failure` | refused | **delivered** |
| the same, with a certificate from an untrusted CA | refused | refused |
| the same, with a wrong host name | refused | refused |

This was not run on macOS, where the forum reports come from, and the probe did not capture the text of MailKit's error.

`SendMailCertificateOptionsTests`, `ReportHelper*Tests` and `SslCertificateValidatorTests`: 32 passed, 1 skipped, on Windows. No new warnings in the changed files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

