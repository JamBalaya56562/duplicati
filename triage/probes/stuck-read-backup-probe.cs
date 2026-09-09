#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): back up a folder reached through a network redirector, holding a
// file whose read stops answering (a WSL FIFO read through \\wsl.localhost), and abort once the
// backup has opened it. Does the backup return?
[NonParallelizable]
public class RedirectedStuckReadProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEREDIR " + msg);

    [Test]
    public async Task AbortWhileReadingThroughTheRedirector()
    {
        var source = Environment.GetEnvironmentVariable("PROBE_SOURCE");
        var marker = Environment.GetEnvironmentVariable("PROBE_MARKER");
        if (source == null || marker == null)
            Assert.Ignore("PROBE_SOURCE and PROBE_MARKER not set");

        var options = new Dictionary<string, string>(TestOptions)
        {
            ["log-file"] = Path.Combine(BASEFOLDER, "redir.log"),
            ["log-file-log-level"] = "verbose",
        };

        using var c = new Controller("file://" + TARGETFOLDER, options, null);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var backupTask = Task.Run(async () => await c.BackupAsync(new[] { source }));

        while (!File.Exists(marker) && sw.Elapsed < TimeSpan.FromSeconds(60) && !backupTask.IsCompleted)
            await Task.Delay(200);
        W($"the read got stuck: {File.Exists(marker)} after {sw.ElapsedMilliseconds} ms, backup finished already: {backupTask.IsCompleted}");
        await Task.Delay(2000);
        W($"backup still running before the abort: {!backupTask.IsCompleted}");

        await c.AbortAsync();
        sw.Restart();
        var returned = await Task.WhenAny(backupTask, Task.Delay(TimeSpan.FromSeconds(30))) == backupTask;
        W($"returned within 30 s of the abort: {returned} ({sw.ElapsedMilliseconds} ms), outcome {(returned ? (backupTask.IsFaulted ? backupTask.Exception!.InnerException!.GetType().Name : backupTask.IsCanceled ? "canceled" : "result") : "-")}");

        foreach (var line in File.ReadAllLines(Path.Combine(BASEFOLDER, "redir.log")))
            if (line.Contains("pipe"))
                W("log: " + (line.Length > 250 ? line.Substring(0, 250) : line));
    }
}
