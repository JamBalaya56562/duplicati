Title: Warn when the USN journal is too small to reach the previous backup

## What happens

The default USN journal on a Windows system drive is 32 MB. On this test machine it held only about two hours and twenty minutes of changes (`fsutil usn queryjournal C:`: maximum size 32 MB, the oldest record from 20:27 at 22:45). With a daily backup, the entries since the previous backup are gone, so every backup scans the volume in full. This also happens with `--usn-policy=required`, and it was logged only as information.

Resolving every record left in the journal to a path worked, so on this machine the full scans in #4175 came from the purged journal, not from records whose path cannot be resolved.

## The change

- A purged journal now throws `UsnJournalPurgedException`, a `UsnJournalSoftFailureException`. Its message gives the journal's maximum size and an `fsutil usn createjournal` command to enlarge it.
- When `--usn-policy` is `on` or `required`, the full scan for this reason is logged as a warning (`UsnJournalPurged`), because it repeats on every backup until the journal is enlarged.
- With `auto`, and for the other reasons for a full scan (such as the first backup), the message stays information.

## Testing

- `UsnJournalPurgedLogTests` (new, 4 tests) and `UsnSourceFileFilterTests` pass.
- An elevated run on C: with `--usn-policy=required` gave these results:
  1. The first backup logged the information as before.
  2. The unchanged backup used the journal.
  3. After about 120,000 file creations and deletions pushed the journal past the previous backup, the backup logged:
     `Warning ... UsnJournalPurged: Performing full scan for volume "C:\": USN journal entries were purged since last scan. The USN journal of C: holds at most 32.00 MiB, which does not reach back to the previous backup. To use the USN journal, make it larger, for example with "fsutil usn createjournal m=1073741824 a=134217728 C:".`
  4. With `auto`, the same text is logged as information.
  5. The restore returned the latest content.

Refs #4175

🤖 Generated with [Claude Code](https://claude.com/claude-code)
