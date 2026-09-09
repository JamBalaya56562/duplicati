#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): the cost of opening each source file on its own task and
// waiting for it with WaitAsync, as the file block processor now does, against opening it
// directly, for many small cached files.
[NonParallelizable]
public class OpenCostProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEOPEN " + msg);

    // As SnapshotBase.OpenReadAsync opens a source file: synchronously, before returning the task
    private static Task<Stream> OpenLikeTheSnapshot(string path)
        => Task.FromResult<Stream>(File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));

    private static async Task<double> OpenAllAsync(string[] files, bool onItsOwn, CancellationToken token)
    {
        var sw = Stopwatch.StartNew();
        foreach (var f in files)
        {
            Stream s;
            if (onItsOwn)
                s = await Task.Run(() => OpenLikeTheSnapshot(f), CancellationToken.None).WaitAsync(token);
            else
                s = await OpenLikeTheSnapshot(f);
            s.Dispose();
        }
        return sw.Elapsed.TotalMilliseconds;
    }

    [Test]
    public async Task CostOfOpeningOnItsOwn()
    {
        var files = new string[20000];
        for (var i = 0; i < files.Length; i++)
        {
            files[i] = Path.Combine(DATAFOLDER, $"f{i}");
            File.WriteAllBytes(files[i], new byte[] { 1 });
        }

        using var cts = new CancellationTokenSource();
        await OpenAllAsync(files, false, cts.Token);
        await OpenAllAsync(files, true, cts.Token);

        double direct = 0, own = 0;
        for (var round = 1; round <= 5; round++)
        {
            var a = await OpenAllAsync(files, false, cts.Token);
            var b = await OpenAllAsync(files, true, cts.Token);
            direct += a;
            own += b;
            W($"round {round}: direct {a:0} ms, on its own task {b:0} ms");
        }
        W($"total: direct {direct:0} ms, on its own task {own:0} ms, difference per open {(own - direct) / (5.0 * files.Length) * 1000:0.0} us");
    }
}
