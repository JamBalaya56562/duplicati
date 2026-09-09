#nullable enable

using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): the stream Duplicati reads with when --backup-privileges is on
// (BackupDataStream, BackupRead). With its read stuck, does cancelling the token end
// ReadAsync, and does WaitAsync end the wait?
[NonParallelizable]
public class BackupDataStreamProbeTests
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEBDS " + msg);

    [Test]
    public async Task StuckBackupRead()
    {
        var path = Environment.GetEnvironmentVariable("PROBE_PATH");
        if (!OperatingSystem.IsWindows() || path == null)
            Assert.Ignore("Windows with PROBE_PATH only");

        using var s = Library.Snapshots.Windows.WindowsShimLoader.NewBackupDataStream(path!);
        W($"opened {path} as {s.GetType().FullName}");

        var buf = new byte[4096];
        using var cts = new CancellationTokenSource();
        var read = s.ReadAsync(buf, 0, buf.Length, cts.Token);
        await Task.Delay(1000);
        W($"read still pending after 1 s: {!read.IsCompleted}{(read.IsCompleted ? ", status " + read.Status + (read.IsFaulted ? " " + read.Exception!.InnerException!.Message : " read " + read.Result) : "")}");

        cts.Cancel();
        var endedOnCancel = await Task.WhenAny(read, Task.Delay(3000)) == read;
        W($"ReadAsync ended within 3 s of the cancel: {endedOnCancel}");

        using var cts2 = new CancellationTokenSource();
        var wrapped = Task.Run(async () => await read.WaitAsync(cts2.Token));
        cts2.CancelAfter(500);
        var wrappedEnded = await Task.WhenAny(wrapped, Task.Delay(3000)) == wrapped;
        W($"waiting on it through WaitAsync ended within 3 s of that cancel: {wrappedEnded}, {(wrappedEnded ? wrapped.Status.ToString() : "-")}");
    }
}
