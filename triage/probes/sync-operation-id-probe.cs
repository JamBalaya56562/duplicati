#nullable enable

using System;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using Duplicati.Library.SQLiteHelper;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): which Operation row does a backup's result and log attach to,
// when a remote synchronization ran at the end of it?
public class SyncOperationIdProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBESYNCOP " + msg);

    [Test]
    [Category("RemoteSync")]
    public async Task WhereTheBackupResultGoes([Values(false, true)] bool withSync)
    {
        File.WriteAllText(Path.Combine(DATAFOLDER, "testfile.txt"), "test content");
        var dest = Path.Combine(BASEFOLDER, "sync-dest");
        Directory.CreateDirectory(dest);

        var options = TestOptions;
        if (withSync)
            options["remote-sync-json-config"] = $@"{{""destinations"": [{{""url"": ""file://{dest.Replace(Path.DirectorySeparatorChar, '/')}""}}]}}";
        options["dbpath"] = DBFILE;

        for (var run = 1; run <= 2; run++)
        {
            File.WriteAllText(Path.Combine(DATAFOLDER, $"file{run}.txt"), $"content {run}");
            using var console = new CommandLine.ConsoleOutput(Console.Out, options);
            using var controller = new Controller($"file://{TARGETFOLDER}", options, console);
            var result = await controller.BackupAsync([DATAFOLDER]);
            W($"withSync={withSync} run {run}: {result.ParsedResult}, sync results: {result.RemoteSynchronizationResults?.Length ?? 0}");
        }

        using var db = await SQLiteLoader.LoadConnectionAsync(DBFILE);
        using (var cmd = db.CreateCommand())
        {
            cmd.CommandText = @"SELECT ""ID"", ""Description"", ""Timestamp"" FROM ""Operation"" ORDER BY ""ID""";
            using var rd = await cmd.ExecuteReaderAsync();
            while (await rd.ReadAsync())
                W($"withSync={withSync} Operation {rd.GetInt64(0)} {rd.GetString(1)} ts={rd.GetInt64(2)}");
        }
        using (var cmd = db.CreateCommand())
        {
            cmd.CommandText = @"SELECT ""OperationID"", ""Type"", COUNT(*) FROM ""LogData"" GROUP BY ""OperationID"", ""Type"" ORDER BY ""OperationID"", ""Type""";
            using var rd = await cmd.ExecuteReaderAsync();
            while (await rd.ReadAsync())
                W($"withSync={withSync} LogData op={rd.GetInt64(0)} type={rd.GetString(1)} rows={rd.GetInt64(2)}");
        }
        using (var cmd = db.CreateCommand())
        {
            cmd.CommandText = @"SELECT ""OperationID"", COUNT(*) FROM ""RemoteOperation"" GROUP BY ""OperationID"" ORDER BY ""OperationID""";
            using var rd = await cmd.ExecuteReaderAsync();
            while (await rd.ReadAsync())
                W($"withSync={withSync} RemoteOperation op={rd.GetInt64(0)} rows={rd.GetInt64(1)}");
        }
        using (var cmd = db.CreateCommand())
        {
            cmd.CommandText = @"SELECT ""ID"", ""OperationID"" FROM ""Fileset"" ORDER BY ""ID""";
            using var rd = await cmd.ExecuteReaderAsync();
            while (await rd.ReadAsync())
                W($"withSync={withSync} Fileset {rd.GetInt64(0)} op={rd.GetInt64(1)}");
        }
    }
}
