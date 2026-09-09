using System;
using System.Diagnostics;
using System.Linq;
using System.Text;
using Duplicati.Library.Utility;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Temporary probe for the review of #7757; not committed
[TestFixture]
public class ZzProbeHtmlRedactionTests
{
    [TestCase("<p>Backup</p><p>/home/someone/secret</p>", "<p>Backup</p><p>-redacted-</p>")]
    [TestCase("<td>Duplicati</td><td>/var/secret</td>", "<td>Duplicati</td><td>-redacted-</td>")]
    [TestCase("a < b and c > d", "a < b and c > d")]
    [TestCase("1 &lt; 2 &amp;&amp; /home/secret &gt; 3", "1 &lt; 2 &amp;&amp; -redacted- &gt; 3")]
    [TestCase("<p>see https://example.com/a/b</p>", "<p>see https://example.com/a/b</p>")]
    [TestCase("<p>Size 1/2 done</p>", null)]
    [TestCase("<p>(/home/secret)</p>", "<p>(-redacted-)</p>")]
    [TestCase("<pre>Error: /home/secret: denied</pre>", null)]
    [TestCase("<p>a</p>\n<p>/srv/x</p>", null)]
    public void Probe(string html, string expected)
    {
        var result = SensitiveDataFilter.RedactPathsInHtml(html);
        TestContext.Progress.WriteLine($"PROBE in=[{html}] out=[{result}] plain=[{SensitiveDataFilter.RedactPaths(html)}]");
        Assert.That(result, Does.Not.Contain("secret"));
        if (expected != null)
            Assert.That(result, Is.EqualTo(expected));
    }

    [TestCase(100_000)]
    [TestCase(1_000_000)]
    [TestCase(4_000_000)]
    public void ProbeTime(int size)
    {
        var line = "<tr><td>2026-11-10 10:00:00</td><td>Warning: cannot read /home/someone/folder/file.txt &amp; more</td></tr>\n";
        var sb = new StringBuilder();
        while (sb.Length < size)
            sb.Append(line);
        var html = sb.ToString();

        GC.Collect();
        var before = GC.GetTotalAllocatedBytes(true);
        var sw = Stopwatch.StartNew();
        var result = SensitiveDataFilter.RedactPathsInHtml(html);
        sw.Stop();
        var allocated = GC.GetTotalAllocatedBytes(true) - before;

        var sw2 = Stopwatch.StartNew();
        SensitiveDataFilter.RedactPaths(html);
        sw2.Stop();

        TestContext.Progress.WriteLine($"PROBE size={html.Length} html={sw.ElapsedMilliseconds}ms alloc={allocated / 1024 / 1024}MB plain={sw2.ElapsedMilliseconds}ms");
        Assert.That(result, Does.Not.Contain("someone"));
    }
}
