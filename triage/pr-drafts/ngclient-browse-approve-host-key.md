Repository: duplicati/ngclient

Title: Ask to approve an unknown SSH host key before browsing

## What happens

On an SFTP destination that was not tested yet, "Browse ..." showed an error asking to add `--ssh-fingerprint=...`. "Test now" asks "Approve host key?" in the same situation, but the folder listing can only report the unknown host key as an error.

## The change

When the URL is an SSH URL with neither `ssh-fingerprint` nor `ssh-accept-any-fingerprints`, "Browse ..." first runs a read-only connection test without dialogs. If the test reports a host key, it runs the test again with dialogs, so the same "Approve host key?" dialog as "Test now" is shown. After the key is approved, the URL gets the fingerprint and the folder browser opens with it. If the key is not approved, the browser does not open. Other destinations open the browser at once, as before.

## Checked

- New tests in `single-destination.component.spec.ts`: three fail without the change and pass with it. They cover the approval, the declined key and a test that reports no key. Three more check that no test runs with an approved key, with any key accepted, and for a destination other than SSH. All 24 tests in the folder pass.
- In the running app with an OpenSSH server on localhost, "Browse ..." showed "Approve host key?". After approving, the folder browser listed the server's folders, the picked folder filled in the path, and the fingerprint stayed in the advanced options. "Test now" then connected without asking again.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
