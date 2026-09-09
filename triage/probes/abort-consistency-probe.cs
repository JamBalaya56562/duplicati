#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using Microsoft.Data.Sqlite;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): what an abort in the middle of a backup leaves in the local
// database and at the destination, and whether the next backup and a full test are clean.
[NonParallelizable]
public class AbortConsistencyProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEABORT " + msg);
    private static int s_failures;

    private string Db(Dictionary<string, string> options)
    {
        var parts = new List<string>();
        using var con = new SqliteConnection($"Data Source={options["dbpath"]};Mode=ReadOnly;Pooling=False");
        con.Open();
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = @"SELECT ""Type"", ""State"", COUNT(*) FROM ""RemoteVolume"" GROUP BY ""Type"", ""State"" ORDER BY 1, 2";
            using var r = cmd.ExecuteReader();
            while (r.Read())
                parts.Add($"{r.GetString(0)}/{r.GetString(1)}={r.GetInt64(2)}");
        }
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = @"SELECT COUNT(*) FROM ""Fileset""";
            parts.Add("filesets=" + cmd.ExecuteScalar());
        }
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = @"SELECT ""Value"" FROM ""Configuration"" WHERE ""Key"" = 'terminated-with-active-uploads'";
            parts.Add("terminatedWithActiveUploads=" + (cmd.ExecuteScalar() ?? "-"));
        }
        return string.Join(" ", parts);
    }

    private string Remote()
    {
        var names = Directory.GetFiles(TARGETFOLDER).Select(Path.GetFileName).ToList();
        return $"remote dblock={names.Count(n => n!.Contains(".dblock."))} dindex={names.Count(n => n!.Contains(".dindex."))} dlist={names.Count(n => n!.Contains(".dlist."))}";
    }

    private void WriteFiles(int count, int size, int seed)
    {
        var rng = new Random(seed);
        var data = new byte[size];
        for (var i = 0; i < count; i++)
        {
            rng.NextBytes(data);
            var dir = Path.Combine(DATAFOLDER, $"d{i / 500}");
            Directory.CreateDirectory(dir);
            File.WriteAllBytes(Path.Combine(dir, $"f{i}"), data);
        }
    }

    [Test]
    public async Task AbortMidBackupThenContinue()
    {
        const int files = 3000;
        var options = new Dictionary<string, string>(TestOptions)
        {
            ["no-encryption"] = "true",
            ["dblock-size"] = "1mb",
            ["log-file-log-level"] = "Profiling",
        };

        WriteFiles(files, 20 * 1024, 1);
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));
        W($"after the first backup: {Db(options)} | {Remote()}");

        var delays = new[] { 300, 700, 1200, 2000, 3000, 4500 };
        for (var attempt = 0; attempt < delays.Length; attempt++)
        {
            // New content for every file, so the next backup uploads many volumes
            WriteFiles(files, 20 * 1024, 100 + attempt);

            var logfile = Path.Combine(BASEFOLDER, $"probe-abort-{attempt}.log");
            if (File.Exists(logfile))
                File.Delete(logfile);
            var abortOptions = new Dictionary<string, string>(options) { ["log-file"] = logfile };

            Exception? error = null;
            using (var c = new Controller("file://" + TARGETFOLDER, abortOptions, null))
            {
                var run = Task.Run(async () => await c.BackupAsync([DATAFOLDER]));
                await Task.Delay(delays[attempt]);
                await c.AbortAsync();
                if (await Task.WhenAny(run, Task.Delay(TimeSpan.FromSeconds(120))) != run)
                {
                    W($"attempt {attempt} abort after {delays[attempt]} ms: the backup did not return within 120 s of the abort");
                    Assert.Fail("The aborted backup did not return");
                }
                try { await run; }
                catch (Exception ex) { error = ex; }
            }

            var log = File.Exists(logfile) ? File.ReadAllLines(logfile) : [];
            var rollback = log.Any(l => l.Contains("Rollback during transaction dispose"));
            var commits = log.Count(l => l.Contains("CommitTransaction") && l.Contains(" took "));
            W($"attempt {attempt} abort after {delays[attempt]} ms: {(error == null ? "completed" : error.GetType().Name)} | rollback on dispose logged: {rollback}, commits: {commits}");
            W($"  right after the abort: {Db(options)} | {Remote()}");

            // The next backup runs to the end, and a full test checks every volume
            try
            {
                using (var c = new Controller("file://" + TARGETFOLDER, options, null))
                {
                    var r = await c.BackupAsync([DATAFOLDER]);
                    W($"  next backup: {r.ParsedResult}, warnings {r.Warnings.Count()}, errors {r.Errors.Count()} {string.Join(" / ", r.Warnings.Concat(r.Errors).Take(3).Select(m => m.Length > 160 ? m.Substring(0, 160) : m))}");
                }
            }
            catch (Exception ex)
            {
                W($"  next backup THREW: {ex.GetType().FullName}: {ex.Message}");
                foreach (var line in ex.ToString().Split('\n').Take(40))
                    W("    | " + line.TrimEnd());
                s_failures++;
            }
            try
            {
                using (var c = new Controller("file://" + TARGETFOLDER, options, null))
                {
                    var t = await c.TestAsync(long.MaxValue);
                    var failed = t.Verifications.Count(v => v.Value.Any());
                    W($"  full test: {t.ParsedResult}, volumes {t.Verifications.Count()}, with problems {failed}, errors {t.Errors.Count()}");
                }
            }
            catch (Exception ex)
            {
                W($"  full test THREW: {ex.GetType().FullName}: {ex.Message}");
                s_failures++;
            }
            W($"  after: {Db(options)} | {Remote()}");
        }
    }
}
