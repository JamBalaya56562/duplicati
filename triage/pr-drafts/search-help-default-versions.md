## What happens

The help for `search` contradicts itself:

- `--version` says: "If no version is specified the latest backup (version=0) will be used."
- `--all-versions` says: "Searches in all backup sets (this is the default)".

The second is correct. `SearchEntriesHandler` asks `GetFilesetIDsAsync` for the filesets that match the given time and versions. When neither a time nor a version is given, that is every fileset.

I measured this with two backups of a file that changed between them:

| Options | Versions returned |
|---|---|
| none | 1 and 0 |
| `--all-versions=true` | 1 and 0 |
| `--version=0` | 0 |

## The change

The `--version` text now says that all backups are searched when neither a version nor a time is given. Only `help.txt` changes.

## Checked

`Duplicati.CommandLine.exe help search`, built from this branch, shows the new text.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
