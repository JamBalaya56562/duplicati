## What happens

The tray icon logs in with its password to get an access token. It does this when it has no token, and again when the server refuses the one it has.

Each request did this on its own, so requests running at the same time each logged in:

- **At start:** the long poll and the plain status request both logged in.
- **When the token runs out:** two requests refused at the same time each renewed it.

Measured against a stand-in server that counts logins:

- **At start:** 3 logins, for the long poll and two status requests.
- **Token refused:** 2 new logins, for two requests refused together.

## The change

Getting a token now happens one request at a time. A request that had to wait uses the token another request got in the meantime, unless that is the same token it was refused with.

The rest is unchanged:

- A refused token is renewed once.
- A request refused again with the new token fails.
- A wrong password fails.

The requests made while getting a token go through `PerformRequestInternalAsync`, not `PerformRequestAsync`. So they never try to take the lock a second time.

## Checked

`TrayLoginTests` runs against a stand-in server, on Windows (3 runs) and on Linux:

| Test | Before | After |
|---|---|---|
| `RequestsAtStartShareOneLogin` | fails, 3 logins | passes, 1 login |
| `RequestsRefusedTogetherShareOneNewLogin` | fails, 2 new logins | passes, 1 new login |
| `ARequestRefusedAgainAfterANewLoginFails` | passes | passes |
| `AWrongPasswordFails` | passes | passes |

I also checked against a real server, with the tray icon's connection logging in with a password:

1. A status request at start, next to the long poll.
2. Pause from the tray: the long poll saw it within 95 ms.
3. Resume: the long poll saw it within 60 ms.

There were no warnings. `NativeNotifierTests` also pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
