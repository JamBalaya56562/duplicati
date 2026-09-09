using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Logging;
using Duplicati.Library.Main;
using NUnit.Framework;
using Assert = NUnit.Framework.Legacy.ClassicAssert;

namespace Duplicati.UnitTest
{
    // Throwaway probe: the body of AbortedBackupWhileBlocksAreStoredReturnsAsync, but the abort is
    // sent from a log listener at the moment RegisterRemoteVolumeAsync is about to run its INSERT,
    // so it lands right before SqliteCommand.ExecuteReaderAsync, as in the CI failure.
    public class AbortTypeProbe : BasicSetupHelper
    {
        private static readonly string OUT = Environment.GetEnvironmentVariable("ABORT_PROBE_OUT") ?? Path.Combine(Path.GetTempPath(), "abort-probe.txt");

        private async Task<Task> RunAbortedAsync(string label)
        {
            var rng = new Random(42);
            var data = new byte[256 * 1024];
            for (var i = 0; i < 200; i++)
            {
                rng.NextBytes(data);
                File.WriteAllBytes(Path.Combine(this.DATAFOLDER, $"file{i}"), data);
            }

            var options = new Dictionary<string, string>(this.TestOptions)
            {
                ["blocksize"] = "4kb",
                ["dblock-size"] = "1mb",
                ["cpu-intensity"] = "1",
                ["snapshot-policy"] = "off",
            };

            using var c = new Controller("file://" + this.TARGETFOLDER, options, null);
            var sw = Stopwatch.StartNew();
            var fired = 0;
            Task backupTask;
            using (Log.StartScope(e =>
            {
                if (sw.Elapsed > TimeSpan.FromSeconds(1)
                    && e.Level == LogMessageType.Profiling
                    && e.FormattedMessage.Contains("Starting - ExecuteScalarInt64Async")
                    && e.FormattedMessage.Contains("INSERT INTO \"Remotevolume\"")
                    && Interlocked.Exchange(ref fired, 1) == 0)
                    c.AbortAsync().GetAwaiter().GetResult();
            }, e => true))
                backupTask = Task.Run(async () => await c.BackupAsync(new[] { this.DATAFOLDER }));

            var stopped = await Task.WhenAny(backupTask, Task.Delay(TimeSpan.FromSeconds(60))) == backupTask;
            string outcome;
            if (!stopped)
                outcome = "NOT-STOPPED";
            else
            {
                try { await backupTask; outcome = "RESULT"; }
                catch (Exception ex)
                {
                    var frame = ex.StackTrace?.Split('\n').Select(l => l.Trim()).FirstOrDefault(l => !l.StartsWith("at System.Threading")) ?? "";
                    outcome = ex.GetType().Name + " | register=" + (ex.StackTrace?.Contains("RegisterRemoteVolumeAsync") ?? false) + " | " + frame;
                }
            }
            File.AppendAllText(OUT, $"{label}\tfired={fired}\t{outcome}{Environment.NewLine}");
            Assert.IsTrue(stopped, "The abort did not make the backup return within 60 seconds");
            return backupTask;
        }

        [Test]
        public async Task OldAssertion([Range(1, 6)] int run)
        {
            var backupTask = await RunAbortedAsync("old");
            Assert.ThrowsAsync<TaskCanceledException>(async () => await backupTask, "An aborted backup should end with the cancellation, not with a result");
        }

        [Test]
        public async Task NewAssertion([Range(1, 6)] int run)
        {
            var backupTask = await RunAbortedAsync("new");
            Assert.CatchAsync<OperationCanceledException>(async () => await backupTask, "An aborted backup should end with the cancellation, not with a result");
        }
    }
}
