Title: Make the path redaction of HTML report bodies faster

`RedactPathsInHtml` (the HTML mail report body, #7757) made a new string and grew a `List<int>` for every character, twice. For a 4.95 MB report body this took 2.2 to 3.0 seconds and about 580 MB of allocations.

## The change

- `HtmlPart` gets `IsTag`. Plain characters use `html[Start]` instead of a one-character string, and the position map is a fixed-size `int[]`.
- A text without `/`, `\` or `&` is returned as it is: every path form the regular expression finds contains `/` or `\`, and a character reference starts with `&`. Most tag contents are like this.

## Testing

- The output is byte for byte the same as before for 50,001 generated inputs: combinations of symbols, tags, character references and surrogate pairs, and report-shaped bodies.
- 4.95 MB body, Release build, 3 runs each: 915 to 1420 ms and about 470 MB, before 2184 to 2976 ms and 580 MB.
- `SendMailHtmlBodyTests`, `SensitiveDataFilterTests` and `ReportPathRedactionTests`: 59 pass.

I did not add a timing test, as those are unreliable in CI.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
