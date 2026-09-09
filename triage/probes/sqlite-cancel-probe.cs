#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.SQLiteHelper;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): does cancelling the token stop an SQL statement that is running,
// on a connection opened the way Duplicati opens its database?
[NonParallelizable]
public class SqliteCancelProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBESQL " + msg);

    private const string LongQuery = @"
        WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c WHERE x < 300000000)
        SELECT count(*) FROM c";

    [Test]
    public async Task CancelARunningStatement()
    {
        var path = Path.Combine(BASEFOLDER, "cancel.sqlite");
        using var con = SQLiteLoader.LoadConnection(path);

        // How long the statement takes when left alone
        var sw = Stopwatch.StartNew();
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = LongQuery;
            await cmd.ExecuteScalarAsync(CancellationToken.None);
        }
        W($"uncancelled: {sw.ElapsedMilliseconds} ms");

        foreach (var how in new[] { "ExecuteScalarAsync", "ExecuteReaderAsync" })
        {
            using var cts = new CancellationTokenSource(1000);
            using var cmd = con.CreateCommand();
            cmd.CommandText = LongQuery;
            sw.Restart();
            string outcome;
            try
            {
                if (how == "ExecuteScalarAsync")
                    await cmd.ExecuteScalarAsync(cts.Token);
                else
                {
                    using var rd = await cmd.ExecuteReaderAsync(cts.Token);
                    while (await rd.ReadAsync(cts.Token)) { }
                }
                outcome = "completed";
            }
            catch (Exception ex)
            {
                outcome = ex.GetType().Name + ": " + ex.Message;
            }
            W($"{how} with the token cancelled after 1 s: returned after {sw.ElapsedMilliseconds} ms, {outcome}");
        }

        using (var cts = new CancellationTokenSource())
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = LongQuery;
            var run = Task.Run(() => { try { cmd.ExecuteScalar(); return "completed"; } catch (Exception ex) { return ex.GetType().Name + ": " + ex.Message; } });
            await Task.Delay(1000);
            sw.Restart();
            cmd.Cancel();
            var outcome = await run;
            W($"SqliteCommand.Cancel() after 1 s: returned {sw.ElapsedMilliseconds} ms after the cancel, {outcome}");
        }
    }
}
