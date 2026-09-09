#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): time a full backup of 512 MB, three times, each into an empty
// target with a new database
[NonParallelizable]
public class ReadPerfProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEPERF " + msg);

    [Test]
    public async Task TimeFullBackups()
    {
        var rng = new Random(7);
        var data = new byte[16 * 1024 * 1024];
        for (var i = 0; i < 32; i++)
        {
            rng.NextBytes(data);
            File.WriteAllBytes(Path.Combine(DATAFOLDER, $"file{i}"), data);
        }

        for (var run = 1; run <= 3; run++)
        {
            if (File.Exists(DBFILE))
                File.Delete(DBFILE);
            foreach (var f in Directory.GetFiles(TARGETFOLDER))
                File.Delete(f);

            using var c = new Controller("file://" + TARGETFOLDER, TestOptions, null);
            var sw = Stopwatch.StartNew();
            var r = await c.BackupAsync(new[] { DATAFOLDER });
            W($"run {run}: {sw.Elapsed.TotalSeconds:0.00} s, {r.ParsedResult}, examined {r.ExaminedFiles}");
        }
    }
}
