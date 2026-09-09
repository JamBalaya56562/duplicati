Fixes #4091

## Summary

- Adds three report template keys. They are expanded from the result of the operation, in the subject and the body of every report module (send-mail, send-http, XMPP, Telegram):
  - `%BeginTime%` / `%EndTime%`: local time as `yyyy-MM-dd HH:mm:ss`, the default of the `formatDate` template helper
  - `%Duration%`: whole seconds as `hh:mm:ss`, or `d.hh:mm:ss` for a day or more
  - All values use the invariant culture, so they look the same on every machine.
- Backwards compatible:
  - The keys are expanded after the options and extra parameters, so an existing option with the same name keeps its value.
  - Without a result (for example after a fatal error) the keys are removed like any unknown key, as before.
- With the JSON result format, the keys used in the template are added to `Extra`.
- The help text of the message options lists the new keys.

## Testing

- New `ReportTimeTemplateKeysTests` (5 tests) run a report module through `Configure` / `OnStart` / `OnFinish` and check the subject and body passed to `SendMessage`:
  - expansion in the subject and the body
  - the same values in another culture (ar-SA)
  - a result without times
  - an option or extra parameter with the same name
  - the JSON format
- Without the change, 3 of the 5 fail: the keys expand to empty. The two backwards-compatibility tests pass either way. With the change, all 5 pass.
- On the current master, the new tests together with `ReportHelperOperationsTests`, `SendMailHtmlBodyTests`, `ReportPathRedactionTests` and `ReducedReportModuleTests` pass (68 of 68). The build adds no warnings.
- Run on Windows only. No real mail, XMPP or Telegram message was sent; all modules go through the same `ReplaceTemplate`.
- The pages `custom-message-content.md` and `sending-telegram-notifications.md` in duplicati/documentation list the template keys and can be updated after this is merged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
