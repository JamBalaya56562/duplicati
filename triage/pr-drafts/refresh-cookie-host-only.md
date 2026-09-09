Fixes #6042

## What happens

The refresh token cookie (`RefreshToken_<port>`) was set with `Domain = Request.Host.Host` (`Endpoints/V1/Auth.cs`). Behind a reverse proxy that does not pass the Host header on, such as Apache `ProxyPass` without `ProxyPreserveHost`, the server sees the address it is reached on (for example `127.0.0.1`), not the name the browser uses. The browser rejects a cookie for a domain it did not ask for. The comment in the issue shows Firefox logging `Cookie "RefreshToken_8200" has been rejected for invalid domain`. Every refresh then failed with "Authorization failed due to missing cookie", and the login looped.

## The change

- The cookie has no domain, so it is for the host the browser asked, whatever the server sees. The path, `Secure`, `HttpOnly` and `SameSite` are unchanged.
- A cookie that an earlier version set for the domain is a separate cookie of the same name. It would stay, holding a refresh token that has since been replaced, and be sent along with the new one. It is removed whenever the cookie is set, and on logout, along with the new one.

## Checked

`ServerApiIntegrationTests.TheRefreshCookieHasNoDomain_Async` (new) logs in and refreshes with the cookies handled by the test, and checks the refresh cookie each response sets:

| | Before | After |
|---|---|---|
| Login | **red**: the cookie has `domain=127.0.0.1` | no domain |
| Refresh with that cookie | | 200, the new cookie has no domain |

All of `ServerApiIntegrationTests` pass (13).

In a browser (Chromium), against a local server:

| Case | Before | After |
|---|---|---|
| Behind a small reverse proxy that sets `Host: 127.0.0.1:<port>` (as Apache without `ProxyPreserveHost`), browsing `http://duplicati.localhost:<proxy port>` | sign-in 200, then refresh **401 "missing cookie"** (the cookie was rejected) | sign-in 200, three refreshes 200; after logout, refresh is 401 "missing cookie" |
| Signed in on the previous version at `http://duplicati.localhost:<port>`, then the server replaced by this one | | four refreshes 200; the old domain cookie is gone (a refresh from `sub.duplicati.localhost`, which only a domain cookie reaches, gets "missing cookie") |
| The same without removing the old domain cookie | | four refreshes 200, but the old domain cookie is still there (the refresh from `sub.duplicati.localhost` gets "Failed to refresh token", that is, a stale token was sent) |

The last row is why the old cookie is removed: Chromium happened to send the new cookie first, but the old one, with its spent token, was still sent along.

## Not covered

A reverse proxy that serves Duplicati below a path (`/duplicati/`) has other problems: the cookie path `/api/v1/auth/refresh` and the old UI's redirect to `/login.html` do not include the prefix. That is what the original report describes, and it is not changed here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
