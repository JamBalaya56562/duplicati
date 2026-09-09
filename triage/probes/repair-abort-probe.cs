#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): what an abort right after a repair starts does to the local
// database now that a failed open closes its connection (#7366).
[NonParallelizable]
public class RepairAbortProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEREPAIR " + msg);

    private string[] Backups(string dbpath)
        => Directory.GetFiles(Path.GetDirectoryName(dbpath)!, Path.GetFileNameWithoutExtension(dbpath) + ".backup*");

    private static bool IsOpen(string path)
    {
        try
        {
            using (new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) { }
            return false;
        }
        catch (IOException)
        {
            return true;
        }
    }

    [Test]
    public async Task AbortThroughController()
    {
        for (var i = 0; i < 20; i++)
            File.WriteAllBytes(Path.Combine(DATAFOLDER, $"f{i}"), Enumerable.Repeat((byte)i, 50000).ToArray());
        using (var c = new Controller("file://" + TARGETFOLDER, TestOptions, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        var saved = DBFILE + ".saved";
        File.Copy(DBFILE, saved, true);
        W($"database {new FileInfo(DBFILE).Length} bytes");

        const int attempts = 60;
        int logged = 0, moved = 0, moveFailed = 0, readFailed = 0;
        for (var attempt = 0; attempt < attempts; attempt++)
        {
            var delayUs = (attempt % 30) * 100;
            var logfile = Path.Combine(BASEFOLDER, $"probe-repair-{attempt}.log");
            if (File.Exists(logfile))
                File.Delete(logfile);
            var options = new Dictionary<string, string?>(TestOptions)
            {
                ["log-file"] = logfile,
                ["log-file-log-level"] = "Information",
            };
            Exception? error = null;
            using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            {
                var sw = System.Diagnostics.Stopwatch.StartNew();
                var run = Task.Run(() => c.RepairAsync());
                while (sw.Elapsed.TotalMilliseconds * 1000 < delayUs)
                    System.Threading.Thread.SpinWait(50);
                await c.AbortAsync();
                try { await run; }
                catch (Exception ex) { error = ex; }
            }

            var text = File.Exists(logfile) ? File.ReadAllText(logfile) : "";
            if (attempt == 5 && File.Exists(logfile))
                File.Copy(logfile, Environment.GetEnvironmentVariable("PROBE_LOG_COPY") ?? Path.Combine(Path.GetTempPath(), "probe-repair-5.log"), true);
            var renamed = text.Contains("RenamingDatabase");
            var failedRead = text.Contains("FailedToReadLocalDatabase");
            var moveError = text.Split('\n').FirstOrDefault(l => l.Contains("IOException"))?.Trim();
            var backups = Backups(DBFILE);
            if (renamed) logged++;
            if (failedRead) readFailed++;
            if (backups.Length > 0) moved++;
            if (renamed && backups.Length == 0) moveFailed++;
            W($"attempt {attempt} delay {delayUs} us:failedRead={failedRead} renameLogged={renamed} backupFiles={backups.Length} dbSize={(File.Exists(DBFILE) ? new FileInfo(DBFILE).Length : -1)} walLeft={File.Exists(DBFILE + "-wal")} error={error?.GetType().Name} {moveError}");

            foreach (var b in backups)
                File.Delete(b);
            foreach (var extra in new[] { DBFILE + "-wal", DBFILE + "-shm" })
                if (File.Exists(extra))
                    File.Delete(extra);
            File.Copy(saved, DBFILE, true);
        }

        W($"summary: failedRead {readFailed}/{attempts}, renameLogged {logged}/{attempts}, backup file created {moved}/{attempts}, rename logged but no backup {moveFailed}/{attempts}");
    }

    [Test]
    public async Task DirectCancelledRepairLeavesFileOpen()
    {
        File.WriteAllBytes(Path.Combine(DATAFOLDER, "file"), [1, 2, 3]);
        using (var c = new Controller("file://" + TARGETFOLDER, TestOptions, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        var dbpath = Path.Combine(BASEFOLDER, $"probe-repair-{Guid.NewGuid():N}.sqlite");
        File.Copy(DBFILE, dbpath);
        var options = new Options(new Dictionary<string, string?>(TestOptions) { ["dbpath"] = dbpath });

        var results = new RepairResults();
        results.TaskControl.Terminate();
        Exception? error = null;
        using (var backend = new Library.Main.Backend.BackendManager("file://" + TARGETFOLDER, options, results.BackendWriter, results.TaskControl))
        {
            try { await new Library.Main.Operation.RepairHandler(options, results).RunAsync(backend, null!); }
            catch (Exception ex) { error = ex; }
        }

        W($"direct: error={error?.GetType().Name} dbExists={File.Exists(dbpath)} backups={Backups(dbpath).Length} dbOpen={(File.Exists(dbpath) && IsOpen(dbpath))} backupOpen={string.Join(",", Backups(dbpath).Select(IsOpen))}");
    }
}
