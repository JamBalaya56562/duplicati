Fixes #6819

The SMB backend created `SMB2Client` with no arguments, so it only offered the SMB 2.0.2–3.0 dialects. A server configured with `server min protocol = SMB3_11` (as in the report) rejects that negotiation, and the backend fails with "Failed to connect to server".

SMBLibrary 1.5.5 added a constructor argument that offers SMB 3.1.1. This PR:

- bumps `SMBLibrary` to 1.5.8.1 and `SMBLibrary.Win32` to 1.5.8 (the latest of each);
- adds an `enable-smb311` backend option that passes that argument to `SMB2Client`;
- adds `TestSmb311Required` to the CIFS live tests, running Samba with `server min protocol = SMB3_11`, `server signing = mandatory` and `smb encrypt = required`. Both tests bind host port 445, so the container is now stopped in a `finally`.

The option is off by default because SMBLibrary itself leaves SMB 3.1.1 off and its author describes the client support as experimental (TalAloni/SMBLibrary#285). Turning it on for everyone would change the negotiated dialect for every modern Windows/Samba server.

Side effects of the bump: without the option, SMBLibrary now also offers SMB 3.0.2 (enabled by default since 1.5.5), and since 1.5.8 it requests a DFS referral before TreeConnect, falling back to a direct tree connect when there is none.

Verification:
- Fork CI, CIFS Tests (ubuntu): with only the new test on master, `TestSmb311Required` fails with `Error listing content: Failed to connect to server localhost`; with this change both `TestSmb` and `TestSmb311Required` pass.
- Locally against Samba 4.15 containers: the strict server fails before the change and passes with `enable-smb311=true`; a default Samba passes both with and without the option.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
