On the second problem (the two PDFs missing when "temporary files" are excluded): that exclusion is the file attribute, not a name or folder. It sets `--exclude-files-attributes=temporary`, so a file with the Windows Temporary attribute is skipped, whatever its name. `dir /a` and `attrib` do not show that attribute, which would explain why the files looked normal. PowerShell shows it: `(Get-Item "file.pdf").Attributes`.

I checked it on current master on Windows 11, with a folder `!Houses` holding `normal.pdf` and a copy that has the Temporary attribute (`attrib` shows `A` for both):

- with `--exclude-files-attributes=temporary`, only `normal.pdf` is in the backup;
- without it, both are.

So this looks like the attribute working as designed, not a lost file. For the original "not associated blocks" error, ts678 found the likely fix in 2.0.1.23 above; I did not test that part. If nobody sees either problem on a current version, I think this can be closed.
