## Summary

`UpdaterManager.CheckForUpdate` and `UpdaterManager.DownloadUpdate` add the user agent with `request.Headers.Add(HttpRequestHeader.UserAgent.ToString(), ...)`. `HttpRequestHeader.UserAgent.ToString()` is `"UserAgent"`, not `"User-Agent"`, so the update check and the package download send a custom `UserAgent` header and no `User-Agent` at all.

This was correct before the WebClient to HttpClient move: [2ba86487ab9494543184ad90e5625d34a26c256d](https://github.com/duplicati/duplicati/commit/2ba86487ab9494543184ad90e5625d34a26c256d) used `wc.Headers.Add(HttpRequestHeader.UserAgent, ...)`, which WebClient maps to `User-Agent`. [c7c46aed7d1688f51440caca5bd01a2e7b8acfbb](https://github.com/duplicati/duplicati/commit/c7c46aed7d1688f51440caca5bd01a2e7b8acfbb) changed it to the `.ToString()` form.

The fix uses the literal `"User-Agent"`, as `JSONWebHelperHttpClient` and `B2AuthHelper` already do. The header value is unchanged.

## Testing

A small console app that references `Duplicati.Library.AutoUpdater` points `AUTOUPDATER_Duplicati_URLS` at a local `HttpListener`, then calls `UpdaterManager.CheckForUpdate()` and `UpdaterManager.DownloadUpdate(...)`. The listener prints the headers it receives:

Before:
```
--- GET /manifest
Request.UserAgent = []
  header UserAgent: Duplicati v1.0.0.0 -ba4f859d44d94b398d55d953647702b3
--- GET /package.zip
Request.UserAgent = []
  header UserAgent: Duplicati v1.0.0.0
```

After:
```
--- GET /manifest
Request.UserAgent = [Duplicati v1.0.0.0 -ba4f859d44d94b398d55d953647702b3]
  header User-Agent: Duplicati v1.0.0.0 -ba4f859d44d94b398d55d953647702b3
--- GET /package.zip
Request.UserAgent = [Duplicati v1.0.0.0]
  header User-Agent: Duplicati v1.0.0.0
```

`Duplicati.Library.AutoUpdater` builds with no warnings in `UpdaterManager.cs`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
