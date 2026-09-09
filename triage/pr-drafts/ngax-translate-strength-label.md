# Make the passphrase strength label of the old UI translatable

This fixes the first point of #2680: on the add backup page of the old UI, the word "Strength" before the passphrase strength cannot be translated.

The label was a string literal inside an expression, `{{PassphraseScore != 'x' ? 'Strength: ' : ''}}`, which the string extraction does not see, so it is not in `localization_webroot.pot` and stays in English in every language. The strength values after it ("Weak", "Strong", ...) are already translated with `gettextCatalog.getString` in `EditBackupController.js`.

The label is now `<span ng-if="PassphraseScore != 'x'" translate>Strength:</span>`, as the other translated labels in the same template are written. It is still shown only when the two passphrases match. The `.pot` file is not changed here, as it is regenerated when the strings are extracted.

The second point of #2680, using the application name instead of "Duplicati" in the strings, is not part of this.

## Testing

On a local server built from this branch, with the browser in Japanese:

- Matching passphrases: the page shows `Strength: 最強`, as before, with "Strength:" now rendered from an element with the `translate` attribute.
- Different passphrases: the page shows only `パスフレーズが一致しません` ("Passphrases do not match"), as before.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
