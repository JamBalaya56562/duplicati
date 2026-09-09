## Summary

`Localizations/duplicati/extract.sh` stripped `\r` from every `.cs` file under `Duplicati/` in place before running `xgettext`. The repository has 177 CRLF and 74 mixed-EOL `.cs` files (`git ls-files --eol`), so every run of the script rewrote 251 source files (49,103 changed lines) that then had to be discarded before committing the new `.pot`.

The stripping itself is needed: without it `xgettext` puts `\r\n` into 4 msgids (multi-line verbatim strings). This change keeps it, but writes the stripped files to a temporary folder and runs `xgettext` there, so the source files are left untouched. The loop now also reads the file list line by line, so `WebserverCore/Services/LoginProvider copy.cs` (a name with a space) is processed instead of making `tr` fail.

Commit: [be3ea82647c826ddd0c0490d2cdc35d2721a941e](https://github.com/JamBalaya56562/duplicati/commit/be3ea82647c826ddd0c0490d2cdc35d2721a941e)

## Testing

Ran on a Linux (WSL, GNU gettext 0.23.2) copy of master [85d15280ad2ab79aa8743a3246dd641b9e8e87c7](https://github.com/duplicati/duplicati/commit/85d15280ad2ab79aa8743a3246dd641b9e8e87c7), comparing md5 sums of all `.cs` files before and after, and the generated `localization.pot` with the `POT-Creation-Date` line removed:

| Script | `.cs` files changed | `.pot` |
|---|---|---|
| before | 251 | 1612 msgids, no `\r` |
| after | 0 | byte-identical to "before" |
| before, without the `tr` loop | 0 | 4 msgids contain `\r\n` |

No temporary folder is left behind in `/tmp` after the run.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
