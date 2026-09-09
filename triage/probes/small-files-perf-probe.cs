#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): time full backups of many small files, twice, each into an
// empty target with a new database. The data is written once per process.
[NonParallelizable]
public class SmallFilesPerfProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBESMALL " + msg);

    [Test]
    public async Task TimeSmallFileBackups()
    {
        var count = int.Parse(Environment.GetEnvironmentVariable("PROBE_FILES") ?? "20000");
        var rng = new Random(11);
        var data = new byte[1024];
        for (var i = 0; i < count; i++)
        {
            rng.NextBytes(data);
            var dir = Path.Combine(DATAFOLDER, $"d{i / 1000}");
            Directory.CreateDirectory(dir);
            File.WriteAllBytes(Path.Combine(dir, $"f{i}"), data);
        }

        for (var run = 1; run <= 2; run++)
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
