#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): the cost of reading a file's size on its own task and waiting
// for it with WaitAsync, against reading it directly, for many small cached files.
[NonParallelizable]
public class StatCostProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBESTAT " + msg);

    private static async Task<double> SizeAllAsync(string[] files, bool onItsOwn, CancellationToken token)
    {
        long total = 0;
        var sw = Stopwatch.StartNew();
        foreach (var f in files)
        {
            if (onItsOwn)
                total += await Task.Run(() => new FileInfo(f).Length).WaitAsync(token);
            else
                total += new FileInfo(f).Length;
        }
        Assert.That(total, Is.EqualTo(files.Length));
        return sw.Elapsed.TotalMilliseconds;
    }

    [Test]
    public async Task CostOfReadingTheSizeOnItsOwn()
    {
        var files = new string[20000];
        for (var i = 0; i < files.Length; i++)
        {
            files[i] = Path.Combine(DATAFOLDER, $"f{i}");
            File.WriteAllBytes(files[i], new byte[] { 1 });
        }

        using var cts = new CancellationTokenSource();
        await SizeAllAsync(files, false, cts.Token);
        await SizeAllAsync(files, true, cts.Token);

        double direct = 0, own = 0;
        for (var round = 1; round <= 5; round++)
        {
            var a = await SizeAllAsync(files, false, cts.Token);
            var b = await SizeAllAsync(files, true, cts.Token);
            direct += a;
            own += b;
            W($"round {round}: direct {a:0} ms, on its own task {b:0} ms");
        }
        W($"total: direct {direct:0} ms, on its own task {own:0} ms, difference per read {(own - direct) / (5.0 * files.Length) * 1000:0.0} us");
    }
}
