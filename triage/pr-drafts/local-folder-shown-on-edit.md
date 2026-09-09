## What happens

In the old web UI (`ngax`), editing a backup whose destination is a local folder sometimes shows the folder browser with nothing selected on the destination step, instead of the saved path, as if no destination had been set.

`templates/backends/file.html` shows the path as a text field when it is set, and the folder browser when it is not. It decided this once, in `ng-init="HideFolderBrowser = ($parent.Path || '') != ''"`, when the template was loaded. The template is loaded as soon as the editor has a backend (`file` is the default), and the job's destination arrives by a separate request. When the job is opened from the home page, the template is already cached and loads first, so `Path` is still empty at that moment; it is filled in right after, but the decision is not made again.

This matches the comments in the issue: it happened for some people and not for others, depending on the order.

## The change

- The parser for the `file` destination makes the same decision when it reads the path, so it is made again whenever a destination is loaded.
- The flag is kept on the editor's scope next to `Path` (`$parent.HideFolderBrowser` in the template, as `$parent.Path` already is), so the template and the parser see the same value. The `ng-init` stays, for the cases where no destination is read (a new backup, or switching the storage type).

Choosing a folder in the browser does not go through the parser, so it does not switch the view. Highlighting the saved folder in the browser was never implemented and still is not.

## Red to green

There is no test framework for the `ngax` scripts, so this was checked by hand in a browser against a server running the web root from this branch (`--webservice-webroot`), with a backup to a local folder.

| | Before | After |
|---|---|---|
| Home, then edit the job (template cached), destination step | **red**, 3 of 3: `Path` set, `HideFolderBrowser` false, the folder browser is shown and the path field hidden | 4 of 4: the path field is shown with the saved folder |
| Load the edit page directly | path field shown | path field shown |
| "Browse" and "Manually type path" | switch views | switch views |
| Choose a folder in the browser | stays on the browser | stays on the browser, `Path` updated |
| Save without changes | | the saved URL is unchanged |
| New backup, local folder | folder browser | folder browser |

The new UI does not have this: its destination step shows the saved folder in the path field, both when loaded directly and when reached from the home page (checked in the browser).

Fixes #4001

🤖 Generated with [Claude Code](https://claude.com/claude-code)
