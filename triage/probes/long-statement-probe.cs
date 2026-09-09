#nullable enable

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): which timed steps and database statements run long on a large
// local database, per operation. Uses the timers Duplicati already logs at the Profiling level
// (the statements it marks as worth logging, the commits and the phases).
[NonParallelizable]
public class LongStatementProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBELONG " + msg);

    private static readonly Regex Slow = new(@"Query still running after (?<s>\d+(\.\d+)?)s in (?<op>[^:]+): (?<q>.*)$", RegexOptions.Compiled);
    private static readonly Regex Took = new(@"\]: (?<what>.*) took (?<d>\d+):(?<h>\d\d):(?<m>\d\d):(?<s>\d\d\.\d+)\s*$", RegexOptions.Compiled);

    private void Report(string op, string logfile, TimeSpan wall)
    {
        var rows = new List<(double Seconds, string What)>();
        foreach (var line in File.ReadLines(logfile))
        {
            var m = Took.Match(line);
            if (!m.Success)
                continue;
            var seconds = int.Parse(m.Groups["d"].Value) * 86400 + int.Parse(m.Groups["h"].Value) * 3600 + int.Parse(m.Groups["m"].Value) * 60
                + double.Parse(m.Groups["s"].Value, CultureInfo.InvariantCulture);
            var what = Regex.Replace(m.Groups["what"].Value, @"\s+", " ");
            rows.Add((seconds, what));
        }

        bool IsSql(string w) => w.StartsWith("Execute", StringComparison.Ordinal);
        var sql = rows.Where(r => IsSql(r.What)).ToList();
        W($"== {op}: wall {wall.TotalSeconds:0.0} s, timed steps {rows.Count}, SQL statements {sql.Count}, SQL over 1 s {sql.Count(r => r.Seconds >= 1)}, longest SQL {(sql.Count == 0 ? 0 : sql.Max(r => r.Seconds)):0.00} s");
        foreach (var r in sql.OrderByDescending(r => r.Seconds).Take(8))
            W($"   SQL {r.Seconds,8:0.000} s  {(r.What.Length > 170 ? r.What.Substring(0, 170) : r.What)}");
        foreach (var r in rows.Where(r => !IsSql(r.What)).OrderByDescending(r => r.Seconds).Take(6))
            W($"   step {r.Seconds,7:0.000} s  {(r.What.Length > 120 ? r.What.Substring(0, 120) : r.What)}");

        // Queries the slow query monitor saw still running, with the longest time it saw for each
        var slow = new Dictionary<string, double>();
        foreach (var line in File.ReadLines(logfile))
        {
            var m = Slow.Match(line);
            if (!m.Success)
                continue;
            var key = m.Groups["op"].Value + ": " + Regex.Replace(m.Groups["q"].Value, @"\s+", " ");
            var s = double.Parse(m.Groups["s"].Value, CultureInfo.InvariantCulture);
            slow[key] = Math.Max(slow.GetValueOrDefault(key), s);
        }
        W($"   slow queries seen (>= 1 s): {slow.Count}");
        foreach (var kv in slow.OrderByDescending(kv => kv.Value).Take(10))
            W($"   SLOW >= {kv.Value,6:0.0} s  {(kv.Key.Length > 220 ? kv.Key.Substring(0, 220) : kv.Key)}");
    }

    private async Task RunAsync(string op, Dictionary<string, string> baseOptions, Func<Controller, Task<IBasicResults>> action, Dictionary<string, string>? extra = null)
    {
        var logfile = Path.Combine(BASEFOLDER, $"probe-long-{op}.log");
        if (File.Exists(logfile))
            File.Delete(logfile);
        var options = new Dictionary<string, string>(baseOptions)
        {
            ["log-file"] = logfile,
            ["log-file-log-level"] = "Profiling",
            ["long-database-query-threshold"] = "1s",
        };
        if (extra != null)
            foreach (var kv in extra)
                options[kv.Key] = kv.Value;

        var sw = Stopwatch.StartNew();
        IBasicResults r;
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            r = await action(c);
        sw.Stop();
        W($"{op}: {r.ParsedResult}, warnings {r.Warnings.Count()}, errors {r.Errors.Count()}");
        Report(op, logfile, sw.Elapsed);
    }

    [Test]
    public async Task ProfileOperationsOnALargeDatabase()
    {
        var files = int.Parse(Environment.GetEnvironmentVariable("PROBE_FILES") ?? "2000");
        var size = int.Parse(Environment.GetEnvironmentVariable("PROBE_FILESIZE") ?? "51200");
        var options = new Dictionary<string, string>(TestOptions)
        {
            ["no-encryption"] = "true",
            ["blocksize"] = "1kb",
            ["no-auto-compact"] = "true",
        };

        var rng = new Random(7);
        var data = new byte[size];
        for (var i = 0; i < files; i++)
        {
            rng.NextBytes(data);
            var dir = Path.Combine(DATAFOLDER, $"d{i / 1000}");
            Directory.CreateDirectory(dir);
            File.WriteAllBytes(Path.Combine(dir, $"f{i}"), data);
        }
        W($"data: {files} files of {size} bytes, blocks of 1 KB: about {(long)files * size / 1024} blocks");

        await RunAsync("backup1", options, async c => await c.BackupAsync([DATAFOLDER]));
        W($"database size after the first backup: {new FileInfo(options["dbpath"]).Length / 1024 / 1024} MB");

        for (var i = 0; i < files; i += 10)
        {
            rng.NextBytes(data);
            File.WriteAllBytes(Path.Combine(DATAFOLDER, $"d{i / 1000}", $"f{i}"), data);
        }
        await RunAsync("backup2-changed", options, async c => await c.BackupAsync([DATAFOLDER]));
        await RunAsync("backup3-unchanged", options, async c => await c.BackupAsync([DATAFOLDER]));
        await RunAsync("delete", options, async c => await c.DeleteAsync(), new() { ["keep-versions"] = "1" });
        await RunAsync("compact", options, async c => await c.CompactAsync(), new() { ["threshold"] = "1" });
        await RunAsync("test", options, async c => await c.TestAsync(3));
        await RunAsync("list", options, async c => await c.ListAsync(Array.Empty<string>(), null!));
        await RunAsync("repair", options, async c => await c.RepairAsync());
        await RunAsync("restore", options, async c => await c.RestoreAsync(null), new() { ["restore-path"] = RESTOREFOLDER });
        W($"database size at the end: {new FileInfo(options["dbpath"]).Length / 1024 / 1024} MB");

        File.Delete(options["dbpath"]);
        await RunAsync("recreate", options, async c => await c.RepairAsync());
    }
}
