# Test that the S3 provider list holds usable Seagate Lyve endpoints

Branch: `test/s3-known-providers`

Lyve Cloud was first added with https:// in the values, which the client
then prefixed with its own scheme. This checks that the five Lyve regions
are listed, and that every known provider that is a full host name is
accepted as the server name by both S3 clients. Suffixes such as
".r2.cloudflarestorage.com" are completed by the editor and are skipped.

Closes #5637

🤖 Generated with [Claude Code](https://claude.com/claude-code)
