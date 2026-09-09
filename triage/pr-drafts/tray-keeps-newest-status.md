## What happens

At start and on reconnect, the tray icon asks for the server state twice: once with a plain request, and once with the long poll it keeps running.

Each answer replaced the state the tray holds, and the event id it waits from, in the order the answers arrived. So if the plain request was answered before a state change, but its answer arrived after the long poll's answer from after the change, the old state came back.

The next long poll was by then already waiting for the event after the newer one. The icon kept the old state until the next change, or until the long poll timed out after five minutes.

## The change

A plain answer is now dropped if the long poll has taken a state since the plain request was sent.

Event ids are not compared, because they start again when the server restarts. If the dropped answer happened to be the newer one, the next long poll brings the change at once, since it waits from the event it has already seen.

## Checked

`TrayStatusOrderTests` runs against a stand-in server that answers the plain request only after the tray has sent its next long poll:

- **Before:** the server was paused at event 2, and the tray kept "running" at event 1. This happened in 3 of 3 runs on Windows, and on Linux.
- **After:** the tray keeps "paused" at event 2, on Windows (3 of 3 runs) and on Linux.

`NativeNotifierTests` also pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
