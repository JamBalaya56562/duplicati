Title: Validate the server certificate in the XMPP report

## What happens

The XMPP report creates the Artalk.Xmpp client without a certificate validation callback. Without one, the client accepts any server certificate after STARTTLS. The report was sent, with the account's login, to a server that had a self-signed certificate, and to one whose certificate had expired in 2022, without any warning.

The HTTP report, the mail report and the backends all validate the certificate, with options to accept a self-signed one.

## The change

The client gets the callback of `SslCertificateValidator`, which the HTTP report and the backends use, so the certificate is validated by default.

For servers with a self-signed certificate, there are three new options, named as the HTTP report's:

- `--send-xmpp-accept-any-ssl-certificate`
- `--send-xmpp-accept-specified-ssl-hash`
- `--send-xmpp-ignore-revocation-failure`

A setup that sends to a server with a self-signed certificate stops getting the report until one of these is set. The failure is logged as a warning, as other send failures are.

## Checked

Against Prosody 0.11.9 (`prosody/prosody` image) with a self-signed certificate, sending from Linux:

| | Before | After |
|---|---|---|
| No option | delivered | refused |
| Hash of another certificate | delivered | refused |
| `--send-xmpp-accept-any-ssl-certificate` | delivered | delivered |
| The server's hash | delivered | delivered |

`SendJabberMessageCertificateTests` uses a stub server that requires STARTTLS and checks whether the client goes on over TLS. Two of the three tests fail before the change. All three pass after it, together with `XmppTargetTests` and `XmppRecipientsTests`, on Windows.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
