#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.SQLiteHelper;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): does sqlite3_interrupt stop a running statement on a connection
// opened the way Duplicati opens its database, and what is left afterwards?
[NonParallelizable]
public class SqliteInterruptProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEINT " + msg);

    private const string LongQuery = @"
        WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c WHERE x < 20000000)
        SELECT count(*) FROM c";

    [Test]
    public async Task InterruptARunningStatement()
    {
        var path = Path.Combine(BASEFOLDER, "interrupt.sqlite");
        using var con = SQLiteLoader.LoadConnection(path);
        using (var setup = con.CreateCommand())
        {
            setup.CommandText = "CREATE TABLE IF NOT EXISTS t (x INTEGER)";
            setup.ExecuteNonQuery();
        }

        var sw = Stopwatch.StartNew();
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = LongQuery;
            cmd.ExecuteScalar();
        }
        W($"uncancelled: {sw.ElapsedMilliseconds} ms, connection type {con.GetType().FullName}");

        // A read, interrupted
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = LongQuery;
            var run = Task.Run(() => { try { cmd.ExecuteScalar(); return "completed"; } catch (Exception ex) { return ex.GetType().Name + ": " + ex.Message; } });
            await Task.Delay(1000);
            sw.Restart();
            SQLitePCL.raw.sqlite3_interrupt(con.Handle);
            var outcome = await run;
            W($"read interrupted after 1 s: returned {sw.ElapsedMilliseconds} ms after the interrupt, {outcome}");
        }

        // A write inside a transaction, interrupted: what is left?
        using (var tr = con.BeginTransaction())
        using (var cmd = con.CreateCommand())
        {
            cmd.Transaction = tr;
            cmd.CommandText = "INSERT INTO t (x) " + LongQuery.Replace("SELECT count(*) FROM c", "SELECT x FROM c");
            var run = Task.Run(() => { try { cmd.ExecuteNonQuery(); return "completed"; } catch (Exception ex) { return ex.GetType().Name + ": " + ex.Message; } });
            await Task.Delay(1000);
            sw.Restart();
            SQLitePCL.raw.sqlite3_interrupt(con.Handle);
            var outcome = await run;
            W($"insert in a transaction interrupted after 1 s: returned {sw.ElapsedMilliseconds} ms after the interrupt, {outcome}");
            try { tr.Rollback(); W("rollback: ok"); } catch (Exception ex) { W("rollback: " + ex.GetType().Name + ": " + ex.Message); }
        }

        // The connection still works afterwards
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = "SELECT count(*) FROM t";
            W($"afterwards: rows in t = {cmd.ExecuteScalar()}");
        }
        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = "PRAGMA integrity_check";
            W($"integrity_check: {cmd.ExecuteScalar()}");
        }
    }
}
