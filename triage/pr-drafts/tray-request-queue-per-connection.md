## What happens

The tray icon sends pause, resume and the other menu actions through a queue that its connection reads.

The queue was a named channel (`Channel.Create(name: "TrayIconRequestQueue")`), and a named CoCoL channel is the same object for everyone asking for that name in the process. Closing a connection retires its queue, so a connection made after it in the same process got a queue that was already retired. Its pause and resume went nowhere, with no error: `WriteNoWait` on a retired channel does not throw.

This is not seen by users. It is a latent fault, and it only shows in code that makes and closes connections in one process, such as tests:

- The tray icon only makes a second connection in the same process in the re-spawn loop in `Program.StartTray`.
- That loop only runs again after Avalonia has been set up, because nothing before `Run` makes an HTTP request.
- Avalonia cannot be set up a second time in a process. Measured: after setting it up with `SetupWithLifetime`, starting it and shutting it down, setting it up again throws `InvalidOperationException: Setup was already called on one of AppBuilder instances`.
- So the second round exits before its menu can be used.

Measured against a real server, with connections made in one process:

- A pause from a first connection reached the server.
- A pause from a connection made after an earlier one was closed did not.

## The change

Each connection now creates its own queue, as an unnamed channel with the same default settings. Nothing else asked for the queue by name, and the tray icon only has one connection at a time, so nothing relied on the sharing.

## Checked

`TrayReconnectTests` runs against a stand-in server. It makes a connection, sends a pause, closes it, makes a second connection, and checks that its pause reaches the server.

| | Before | After |
|---|---|---|
| Windows (3 runs) | fails, the pause never arrives | passes |
| Linux | fails, the pause never arrives | passes |

Against a real server, a pause from a connection made after an earlier one was closed now reaches the server, and a pause from a first connection still does. There were no warnings. `NativeNotifierTests` also pass.

`ProcessBasedActionDelay` also uses named channels (`"UI Action"` and `"UI Initializer"`), with the same latent fault: an instance made after another was disposed fails with `RetiredException`. For the same reason as above it is not seen by users, as there is one per `AvaloniaRunner`. This change does not touch them.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
