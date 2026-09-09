#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Utility;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): the cost of the change itself. Read a cached file block by block
// the way the block splitter does, with and without WaitAsync around each read.
[NonParallelizable]
public class ReadWaitCostProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBECOST " + msg);

    private static async Task<(double seconds, long reads)> ReadAllAsync(string path, int blocksize, bool wrap, CancellationToken token)
    {
        var buf = new byte[blocksize];
        long reads = 0;
        var sw = Stopwatch.StartNew();
        // As SnapshotBase.OpenRead opens a source file
        using (var fs = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            int n;
            while ((n = wrap
                ? await fs.ForceStreamReadAsync(buf, blocksize, token).WaitAsync(token)
                : await fs.ForceStreamReadAsync(buf, blocksize, token)) != 0)
                reads++;
        }
        return (sw.Elapsed.TotalSeconds, reads);
    }

    [Test]
    public async Task CostOfWaitAsync()
    {
        var path = Path.Combine(DATAFOLDER, "big.bin");
        var rng = new Random(3);
        var chunk = new byte[16 * 1024 * 1024];
        using (var f = File.Create(path))
            for (var i = 0; i < 16; i++)
            {
                rng.NextBytes(chunk);
                f.Write(chunk);
            }

        using var cts = new CancellationTokenSource();
        foreach (var blocksize in new[] { 100 * 1024, 1024 * 1024 })
        {
            // Warm the file cache and the code
            await ReadAllAsync(path, blocksize, false, cts.Token);
            await ReadAllAsync(path, blocksize, true, cts.Token);

            double plain = 0, wrapped = 0;
            long reads = 0;
            for (var round = 1; round <= 5; round++)
            {
                var a = await ReadAllAsync(path, blocksize, false, cts.Token);
                var b = await ReadAllAsync(path, blocksize, true, cts.Token);
                plain += a.seconds;
                wrapped += b.seconds;
                reads = a.reads;
                W($"blocksize {blocksize / 1024} KB round {round}: plain {a.seconds * 1000:0} ms, with WaitAsync {b.seconds * 1000:0} ms ({a.reads} reads)");
            }
            W($"blocksize {blocksize / 1024} KB total: plain {plain * 1000:0} ms, with WaitAsync {wrapped * 1000:0} ms, difference per read {(wrapped - plain) / (5.0 * reads) * 1e6:0.0} us");
        }
    }
}
