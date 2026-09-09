Title: Report a missing FTP folder when the listing is refused with another code

## What happens

"Test connection" on an FTP destination whose folder does not exist yet should offer to create the folder. The backend only reads 550 and 450 as "folder missing". pyftpdlib answers MLSD for a missing folder with `501 No such directory.`, so the test failed with that error and did not offer to create the folder.

## The change

When the listing is refused with another code, the backend changes into the folder with CWD (FluentFTP's `DirectoryExists`). If the folder is not there, the error is reported as `FolderMissingException`, so the web UI offers to create it. Servers that answer 550 or 450 work as before, and a folder that exists keeps the server's own error.

## Checked

- `FtpMissingFolderTests` uses a scripted FTP server on localhost. The missing folder test fails before the change (`FtpCommandException: Code: 501`) and passes after it. A refused listing of a folder that exists still gives the 501 error, and a normal listing works.
- Against pyftpdlib on localhost, `/api/v1/remoteoperation/test` now returns `missing-folder`, `autocreate=true` creates the folder, and the next test passes. Before, the test failed with the 501 error.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
