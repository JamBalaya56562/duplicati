A `--send-http-url` with a user and password, such as `https://user:password@host/path`, got a 401 from a server that asks for Basic authentication (#3711). The same URL works in a browser or curl.

`HttpClient` does not use the user information of a URL. With .NET 10.0.14, a request to `http://user:secret@127.0.0.1:<port>/hook` reached the server without an `Authorization` header.

## The change

In `SendHttpMessage.SendMessage`, the user and password of the URL are unescaped and sent as a Basic `Authorization` header. They are removed from the request URL and from the URL in the log messages, which before this change logged the URL as it was given, password included.

## Testing

New `SendHttpMessageTests` runs the module itself (`Configure`, `OnStart`, `OnFinish`) against a local TCP server and checks the request headers it receives:

| test | master | this branch |
|---|---|---|
| `UserInfoInTheUrlIsSentAsBasicAuthentication` (`p%40ss%3Aword` is sent as `p@ss:word`, and the query is kept) | **fail**: no `Authorization` header | pass |
| `UrlWithoutUserInfoSendsNoAuthentication` | pass | pass |

The master column was measured on master when the branch was written.

Rebased on master [744c74dd1](https://github.com/duplicati/duplicati/commit/744c74dd11a6302ab4cbb91c00c6e5e7e91ffa93), on Windows: `SendHttpMessageTests`, 2 passed. Before the rebase, with `ReportHelperOperationsTests`, 10 passed. No warnings in the changed files.

Fixes #3711

🤖 Generated with [Claude Code](https://claude.com/claude-code)
