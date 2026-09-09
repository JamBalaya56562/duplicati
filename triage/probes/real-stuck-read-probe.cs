#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): with a real OS handle opened for synchronous reads, and a read
// stuck because the other end sends nothing, does cancelling the token end ReadAsync, and does
// WaitAsync(token) end the wait?
[NonParallelizable]
public class RealStuckReadProbeTests
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEREAL " + msg);

    [Test]
    public async Task StuckSynchronousRead()
    {
        string path;
        IDisposable otherEnd;
        if (Environment.GetEnvironmentVariable("PROBE_PATH") is string given)
        {
            path = given;
            otherEnd = new Disposer(() => { });
        }
        else if (OperatingSystem.IsWindows())
        {
            var name = "duplicati-probe-" + Guid.NewGuid().ToString("N");
            var server = new NamedPipeServerStream(name, PipeDirection.Out, 1, PipeTransmissionMode.Byte, PipeOptions.None);
            path = @"\\.\pipe\" + name;
            var connected = server.WaitForConnectionAsync();
            otherEnd = server;
            _ = connected;
        }
        else
        {
            path = Path.Combine(Path.GetTempPath(), "duplicati-probe-" + Guid.NewGuid().ToString("N"));
            Process.Start("mkfifo", path)!.WaitForExit();
            var opened = new ManualResetEventSlim();
            FileStream? writer = null;
            new Thread(() => { writer = new FileStream(path, FileMode.Open, FileAccess.Write); opened.Set(); }) { IsBackground = true }.Start();
            otherEnd = new Disposer(() => { opened.Wait(5000); writer?.Dispose(); });
        }

        // As SnapshotBase.OpenRead opens a source file: synchronous, FileShare.ReadWrite
        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        W($"opened {path}, IsAsync={fs.IsAsync}");

        var buf = new byte[4096];
        using var cts = new CancellationTokenSource();
        var read = fs.ReadAsync(buf, 0, buf.Length, cts.Token);
        await Task.Delay(1000);
        W($"read still pending after 1 s: {!read.IsCompleted}");

        cts.Cancel();
        var endedOnCancel = await Task.WhenAny(read, Task.Delay(3000)) == read;
        W($"ReadAsync ended within 3 s of the cancel: {endedOnCancel}");

        var wait = Task.Run(async () => await fs.ReadAsync(buf, 0, buf.Length, CancellationToken.None).WaitAsync(cts.Token));
        var waitEnded = await Task.WhenAny(wait, Task.Delay(3000)) == wait;
        W($"a new read with WaitAsync(cancelled token) ended within 3 s: {waitEnded}, {(waitEnded ? wait.Status.ToString() : "-")}");

        using var cts2 = new CancellationTokenSource();
        var read2 = fs.ReadAsync(buf, 0, buf.Length, CancellationToken.None).WaitAsync(cts2.Token);
        await Task.Delay(500);
        cts2.Cancel();
        var ended2 = await Task.WhenAny(read2, Task.Delay(3000)) == read2;
        W($"a read wrapped in WaitAsync ended within 3 s of the cancel: {ended2}, {(ended2 ? read2.Status.ToString() : "-")}");

        // As FileBlockProcessor does when the splitter gives up: dispose the stream with the read still stuck
        var sw = Stopwatch.StartNew();
        var dispose = Task.Run(() => fs.Dispose());
        var disposed = await Task.WhenAny(dispose, Task.Delay(5000)) == dispose;
        W($"disposing the stream with the read stuck returned within 5 s: {disposed} ({sw.ElapsedMilliseconds} ms), read still pending: {!read.IsCompleted}");

        sw.Restart();
        otherEnd.Dispose();
        var endedOnClose = await Task.WhenAny(read, Task.Delay(5000)) == read;
        W($"the stuck read ended once the other end closed: {endedOnClose} after {sw.ElapsedMilliseconds} ms, status {read.Status}");
        if (!disposed)
            W($"dispose returned after the other end closed: {await Task.WhenAny(dispose, Task.Delay(5000)) == dispose}");
    }

    private sealed class Disposer(Action a) : IDisposable
    {
        public void Dispose() => a();
    }
}
