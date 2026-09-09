#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): does "Stop now" while new blocks are flowing leave the backup
// waiting forever on a block hand-off whose receiver left without answering?
[NonParallelizable]
public class AbortHandoffProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEHANDOFF " + msg);

    [Test]
    public async Task AbortWhileBlocksFlow([Values(1200, 2400, 4800)] int abortAfterMs, [Values("10", "1")] string cpu)
    {
        var rng = new Random(abortAfterMs);
        var data = new byte[256 * 1024];
        for (var i = 0; i < 200; i++)
        {
            rng.NextBytes(data);
            File.WriteAllBytes(Path.Combine(DATAFOLDER, $"file{i}"), data);
        }

        var options = new Dictionary<string, string>(TestOptions)
        {
            ["blocksize"] = "4kb",
            ["dblock-size"] = "1mb",
            ["snapshot-policy"] = "off",
            ["cpu-intensity"] = cpu,
        };

        using var c = new Controller("file://" + TARGETFOLDER, options, null);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var backupTask = Task.Run(async () => await c.BackupAsync(new[] { DATAFOLDER }));
        await Task.Delay(abortAfterMs);
        var finishedBeforeAbort = backupTask.IsCompleted;
        await c.AbortAsync();
        var abortedAt = sw.Elapsed;

        var returned = await Task.WhenAny(backupTask, Task.Delay(TimeSpan.FromSeconds(40))) == backupTask;
        var outcome = !returned ? "STILL RUNNING" : backupTask.IsFaulted ? backupTask.Exception!.InnerException!.GetType().Name : backupTask.IsCanceled ? "canceled" : "result";
        W($"cpu {cpu} abort after {abortAfterMs} ms (finished before abort: {finishedBeforeAbort}): returned={returned} after {(sw.Elapsed - abortedAt).TotalSeconds:0.0} s, outcome {outcome}");

    }
}
