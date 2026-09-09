using System.Diagnostics;
using Duplicati.Library.Utility;

// A report body like the HTML mail template with many log lines
static string MakeHtml(int lines)
{
    var sb = new System.Text.StringBuilder("<html><body><h1>Backup report</h1>\n<table>\n");
    for (var i = 0; i < lines; i++)
        sb.Append("<tr><td class=\"t\">2026-11-12 10:00:").Append(i % 60).Append("</td><td>Uploaded C:\\Users\\someone\\Documents\\file-").Append(i)
          .Append(".txt to /backup/target/dir &amp; checked <b>ok</b> &#47;home&#47;x").Append(i).Append("</td></tr>\n");
    sb.Append("</table></body></html>");
    return sb.ToString();
}

var mode = args.Length > 0 ? args[0] : "bench";
if (mode == "regex") { var h = MakeHtml(30000); var t = System.Text.RegularExpressions.Regex.Replace(h, "<[^<>]*>", ""); SensitiveDataFilter.RedactPaths(t); var sw0 = Stopwatch.StartNew(); SensitiveDataFilter.RedactPaths(t); SensitiveDataFilter.RedactPaths(t); Console.WriteLine($"two regex passes over {t.Length / 1048576.0:F2} MB of text: {sw0.ElapsedMilliseconds} ms"); return; }
if (mode == "bench")
{
    foreach (var lines in new[] { 1000, 10000, 30000 })
    {
        var html = MakeHtml(lines);
        SensitiveDataFilter.RedactPathsInHtml(html); // warm up
        GC.Collect();
        var before = GC.GetTotalAllocatedBytes(true);
        var sw = Stopwatch.StartNew();
        var result = SensitiveDataFilter.RedactPathsInHtml(html);
        sw.Stop();
        var alloc = GC.GetTotalAllocatedBytes(true) - before;
        Console.WriteLine($"{html.Length / 1024.0 / 1024.0:F2} MB: {sw.ElapsedMilliseconds} ms, {alloc / 1024 / 1024} MB allocated, len {result.Length}");
    }
}
else
{
    // Write the results for a fixed set of inputs, to compare two implementations
    var inputs = new List<string> { MakeHtml(50) };
    var rnd = new Random(7757);
    var pieces = new[] { "<", ">", "</", "<b>", "</b>", "<p>", "<a href=\"", "\">", "C:\\", "\\", "/", "//", "file:///", "&#47;", "&#x2F;", "&sol;", "&bsol;", "&colon;", "&amp;", "&lt;", "&gt;", "&#", ";", "x", "y", " ", "\n", ".", ":", "_", "<!--", "-->", "\\\\srv", "a", "Z", "&", "\"", "'", "(", ")", "&Tab;", "&NewLine;", "&#0;", "&#xD800;", "<C:\\x>", "<a/b>", "&#128512;", "\u00e9", "\U0001F600" };
    for (var n = 0; n < 50000; n++)
    {
        var sb = new System.Text.StringBuilder();
        var count = rnd.Next(1, 30);
        for (var k = 0; k < count; k++)
            sb.Append(pieces[rnd.Next(pieces.Length)]);
        inputs.Add(sb.ToString());
    }
    using var w = new StreamWriter(args[1]);
    foreach (var input in inputs)
        w.WriteLine(Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(SensitiveDataFilter.RedactPathsInHtml(input))));
    Console.WriteLine($"wrote {inputs.Count} results");
}
