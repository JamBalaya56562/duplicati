#nullable enable

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): what the file backend reports for a destination that cannot be
// reached, and whether the retries carry a restore over a destination that is gone for a while.
[NonParallelizable]
public class OfflineDestinationProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEOFFLINE " + msg);

    [Test]
    public async Task UnreachablePaths()
    {
        var paths = new[]
        {
            Path.Combine(BASEFOLDER, "no-such-folder"),
            @"\\duplicati-no-such-host.invalid\share\target",
            @"\\localhost\duplicati-no-such-share\target",
            @"\\wsl.localhost\duplicati-no-such-distro\tmp",
            @"Q:\duplicati-target",
        };
        foreach (var path in paths)
        {
            var sw = Stopwatch.StartNew();
            string outcome;
            try
            {
                using var backend = Library.DynamicLoader.BackendLoader.GetBackend("file://" + path, new Dictionary<string, string>());
                await foreach (var _ in backend.ListAsync(CancellationToken.None)) { }
                outcome = "listed";
            }
            catch (Exception ex)
            {
                outcome = $"{ex.GetType().FullName}: {ex.Message.Split('\n')[0]}";
            }
            W($"{path} -> {outcome} ({sw.ElapsedMilliseconds} ms)");
        }
    }

    private static void Junction(string link, string target)
    {
        var p = Process.Start(new ProcessStartInfo("cmd", $"/c mklink /J \"{link}\" \"{target}\"") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true })!;
        p.WaitForExit();
        if (!Directory.Exists(link))
            throw new InvalidOperationException("Could not create the junction");
    }

    [Test]
    [TestCase("gone at the start", 0, 15)]
    [TestCase("gone during the restore", 3, 15)]
    [TestCase("gone for longer than the retries", 0, 75)]
    public async Task RestoreOverADestinationThatIsGoneForAWhile(string name, int goneAfterSeconds, int backAfterSeconds)
    {
        if (!OperatingSystem.IsWindows())
            Assert.Ignore("Uses a junction");

        var rng = new Random(3);
        var data = new byte[50 * 1024];
        for (var i = 0; i < 200; i++)
        {
            rng.NextBytes(data);
            File.WriteAllBytes(Path.Combine(DATAFOLDER, $"f{i}"), data);
        }

        // The destination is reached through a junction, which can be removed and put back while
        // files in the folder are open, as a network drive that drops out and comes back
        var link = TARGETFOLDER.TrimEnd(Path.DirectorySeparatorChar) + "-link";
        if (Directory.Exists(link))
            Directory.Delete(link);
        Junction(link, TARGETFOLDER);

        var options = new Dictionary<string, string>(TestOptions)
        {
            ["no-encryption"] = "true",
            ["dblock-size"] = "1mb",
        };
        using (var c = new Controller("file://" + link, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        var restoreOptions = new Dictionary<string, string>(options)
        {
            ["restore-path"] = RESTOREFOLDER,
            ["throttle-download"] = "500kb",
        };

        var sw = Stopwatch.StartNew();
        var outage = Task.Run(async () =>
        {
            await Task.Delay(TimeSpan.FromSeconds(goneAfterSeconds));
            Directory.Delete(link);
            W($"[{name}] destination gone at {sw.Elapsed.TotalSeconds:0.0} s");
            await Task.Delay(TimeSpan.FromSeconds(backAfterSeconds));
            Junction(link, TARGETFOLDER);
            W($"[{name}] destination back at {sw.Elapsed.TotalSeconds:0.0} s");
        });
        if (goneAfterSeconds == 0)
            await Task.Delay(500);

        string outcome;
        try
        {
            using var c = new Controller("file://" + link, restoreOptions, null);
            var restore = c.RestoreAsync(null);
            if (await Task.WhenAny(restore, Task.Delay(TimeSpan.FromMinutes(4))) != restore)
                outcome = "still running after 4 minutes";
            else
            {
                var r = await restore;
                var restored = Directory.GetFiles(RESTOREFOLDER).Length;
                outcome = $"{r.ParsedResult}, restored {restored} of 200 files, warnings {r.Warnings.Count()}, errors {r.Errors.Count()} {string.Join(" / ", r.Errors.Take(2).Select(m => m.Length > 140 ? m.Substring(0, 140) : m))}";
            }
        }
        catch (Exception ex)
        {
            outcome = $"threw {ex.GetType().Name}: {ex.Message.Split('\n')[0]}";
        }
        W($"[{name}] restore ended at {sw.Elapsed.TotalSeconds:0.0} s: {outcome}");
        await outage;
        if (Directory.Exists(link))
            Directory.Delete(link);
    }
}
