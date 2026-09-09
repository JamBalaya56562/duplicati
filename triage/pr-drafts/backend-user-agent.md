## Summary

`HttpRequestHeader.UserAgent.ToString()` returns `"UserAgent"`, not `"User-Agent"`. The WEBDAV and pCloud backends pass it to `request.Headers.Add(...)`, so every request carries a custom `UserAgent:` header and no `User-Agent` at all.

- WEBDAV: regressed in [c7c46aed7d1688f51440caca5bd01a2e7b8acfbb](https://github.com/duplicati/duplicati/commit/c7c46aed7d1688f51440caca5bd01a2e7b8acfbb) (WebClient → HttpClient); before that it set `req.UserAgent`.
- pCloud: present since the backend was added in [4beafc0cc76cd8863f4099883bb5909ecd038ddb](https://github.com/duplicati/duplicati/commit/4beafc0cc76cd8863f4099883bb5909ecd038ddb).

Both `CreateRequest` helpers now use the literal `"User-Agent"`; the value is unchanged.

## Testing

A throwaway console app (not committed) pointed the code at a local `HttpListener` and printed every request header whose name contains "agent". WEBDAV ran against `webdav://localhost:<port>/dav/` via `DeleteAsync`; pCloud's host is fixed, so its private `CreateRequest` was invoked by reflection and the resulting request redirected to the listener.

Before (master):
```
[WEBDAV] DELETE /dav/probe.txt
  UserAgent: Duplicati WEBDAV Client v1.0.0.0
[pCloud] GET /listfolder
  UserAgent: Duplicati pCloud Client v1.0.0.0
```

After:
```
[WEBDAV] DELETE /dav/probe.txt
  User-Agent: Duplicati WEBDAV Client v1.0.0.0
[pCloud] GET /listfolder
  User-Agent: Duplicati pCloud Client v1.0.0.0
```

No new build warnings in the two touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
