Title: Remove the last TODO-DNC block from OAuthHttpClient

## Summary

#4523 asked to look at each `TODO-DNC` marker left from the .NET port. Only one is left on master: a commented-out block in `OAuthHttpClient.CreateMessageHandler` that set a read/write timeout and a certificate validator from `HttpContextSettings`.

That code cannot come back as it was, and nothing is missing without it:

- `HttpContextSettings` no longer exists anywhere in the source; the block is the only place that names it.
- Read/write timeouts are now set for each operation through `TimeoutOptionsHelper`. The Graph backend, the only user of `OAuthHttpClient`, uses `WithTimeout(m_timeouts.ShortTimeout, ...)` for requests and `ObserveReadTimeout(m_timeouts.ReadWriteTimeout)` for downloads.
- Certificate checks are now set for each backend through `SslOptionsHelper` / `HttpClientHelper.ConfigureHandlerCertificateValidator`, for the backends that talk to user-chosen servers (WebDAV and others), not through a global setting.

So the block is dead code rather than a missing feature. This removes it, along with `CreateMessageHandler`, which did nothing else but create the handler. There is no change in behaviour. With this, master has no `TODO-DNC` markers left.

Commit: [624b551a0e55b1019a61450ad89c08c6ef717e49](https://github.com/JamBalaya56562/duplicati/commit/624b551a0e55b1019a61450ad89c08c6ef717e49)

Fixes #4523

## Testing

- `git grep TODO-DNC`: 1 match before (`OAuthHttpClient.cs`), 0 after.
- The build has no warnings.
- `OneDriveUrlTests` (these create `OneDrive` backends, and so `OAuthHttpClient`): 12 passed, 0 failed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
