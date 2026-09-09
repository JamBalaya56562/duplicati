## Summary

Two report modules had the same problem as #7454: one try around the whole loop, so the first failure skipped every target after it.

- `HttpReportStatus.PostAsync`: `--http-report-status-url` takes several URLs (`,` or `;`), but a URL that failed stopped the status report from reaching the URLs after it. Each URL is now posted to on its own, and the warning names the URL that failed (it used to list all of them). Posting stops if the operation was cancelled, so a cancel does not log one warning per URL. A serialization failure is still logged once, as before.
- `SendJabberMessage.SendMessage`: `--send-xmpp-to` takes several recipients, but a recipient whose send threw stopped the message from reaching the recipients after it. The loop is moved into `SendToRecipients`, which tries each recipient on its own and logs the one that failed.

Commit: [1df14446a4acc5f989e0fe23b64c6e19cbcf8b7b](https://github.com/JamBalaya56562/duplicati/commit/1df14446a4acc5f989e0fe23b64c6e19cbcf8b7b)

## Testing

- `HttpReportStatusTests.FailingUrlDoesNotStopTheNextOneAsync`: overrides `SendAsync` to fail for one of two configured URLs and records the URLs posted to. Before the fix: `Missing: "http://localhost/ok"`. After: both URLs are posted to, and one `HttpReportStatusSendError` names only the failing URL.
- `XmppRecipientsTests.FailingRecipientDoesNotStopTheNextOne` / `EveryRecipientIsSentTo`: call `SendToRecipients` with the `--send-xmpp-to` value and a send that throws for the first recipient. Before the fix (the loop extracted unchanged): `Missing: "second@example.com"`. After: both recipients are tried, one `XMPPSendError` names the failing one.
- The XMPP client itself (`ArtalkXmppClient`) is not exercised: that needs an XMPP server.

```
dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --filter "FullyQualifiedName~HttpReportStatusTests|FullyQualifiedName~XmppRecipientsTests|FullyQualifiedName~XmppTargetTests"
before: Failed 2, Passed 34
after:  Passed 36
```

No new compiler warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
