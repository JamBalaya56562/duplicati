This is the recovery tool part of #8005. A parity file (`*.par2`) is parsed as the data volume it belongs to, and is not encrypted. `download` tried to decrypt it and reported an error for each one. For an unencrypted backup it was downloaded as a volume, the index gave errors, and `list` showed each version twice. `recompress` would also have taken it for a volume. They are now left out.

## Tests

`RecoveryToolParityFilesTests`, with and without encryption, fails on master.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
