# Test that an FTP listing that gets no answer times out

Branch: `test/ftp-list-timeout`

A server that stops answering in the middle of a listing, as one that is
rebooted does, used to keep the backup waiting forever. The listing now
runs under --list-timeout. The scripted FTP server can now open the data
connection for a listing and send nothing; with a 2 second list timeout the
listing fails within 10 seconds, where the FTP client's own timeouts take
about 30.

Closes #3509

🤖 Generated with [Claude Code](https://claude.com/claude-code)
