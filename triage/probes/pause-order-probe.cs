using System;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.AutoUpdater;
using Duplicati.Library.RestAPI.Database;
using Duplicati.Library.SQLiteHelper;
using Duplicati.Server;
using Duplicati.Server.Database;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): the state change is sent outside the lock by Resume and by the
// suspend handler. If the two cross, does the queue end up told the wrong state?
public class PauseOrderProbeTests
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEPAUSE " + msg);

    private string _folder = null!;
    private Connection _connection = null!;

    [SetUp]
    public async Task SetUpAsync()
    {
        _folder = Path.Combine(Path.GetTempPath(), $"duplicati-pause-order-{Guid.NewGuid()}");
        Directory.CreateDirectory(_folder);
        var databasePath = Path.Combine(_folder, DataFolderManager.SERVER_DATABASE_FILENAME);
        var db = await SQLiteLoader.LoadConnectionAsync(databasePath);
        DatabaseUpgrader.UpgradeDatabase(db, databasePath, typeof(DatabaseSchemaMarker));
        _connection = new Connection(db, true, null, _folder, () => { });
    }

    [TearDown]
    public void TearDown()
    {
        _connection.Dispose();
        try { Directory.Delete(_folder, true); } catch { }
    }

    private static void Invoke(LiveControls lc, string method)
        => typeof(LiveControls).GetMethod(method, BindingFlags.NonPublic | BindingFlags.Instance)!.Invoke(lc, null);

    // pauser: "suspend" pauses through OnSuspend, "user" through Pause(false)
    [TestCase("suspend")]
    [TestCase("user")]
    public void Probe(string pauser)
    {
        var lc = new LiveControls(_connection);
        W($"{pauser} start: state={lc.State}");

        var queue = "(none)";
        var gate = new object();
        var runningDelivered = new ManualResetEventSlim();
        var pauserThreadId = -1;

        lc.StateChanged = e =>
        {
            // The pausing thread is held up just after it left the lock, before its event lands
            if (e.State == LiveControls.LiveControlState.Paused && Environment.CurrentManagedThreadId == pauserThreadId)
            {
                var got = runningDelivered.Wait(TimeSpan.FromSeconds(3));
                W($"{pauser} pause event held; the resume event arrived meanwhile: {got}");
            }
            lock (gate) queue = e.State.ToString();
            W($"{pauser} queue told: {e.State}");
            if (e.State == LiveControls.LiveControlState.Running)
                runningDelivered.Set();
        };

        var pauseThread = new Thread(() =>
        {
            pauserThreadId = Environment.CurrentManagedThreadId;
            if (pauser == "suspend")
                Invoke(lc, "OnSuspend");
            else
                lc.Pause(false);
        });
        pauseThread.Start();

        // Wait until the state is paused, then resume, as a user or an expired timed pause would
        var until = DateTime.UtcNow.AddSeconds(5);
        while (lc.State != LiveControls.LiveControlState.Paused && DateTime.UtcNow < until)
            Thread.Sleep(10);
        W($"{pauser} state after pausing: {lc.State}");
        var resumeThread = new Thread(() => lc.Resume());
        resumeThread.Start();

        pauseThread.Join(TimeSpan.FromSeconds(10));
        resumeThread.Join(TimeSpan.FromSeconds(10));
        W($"{pauser} after both: state={lc.State}, queue last told={queue}");

        if (pauser == "suspend")
        {
            // Waking up: the resume handler un-pauses what the suspend paused
            Invoke(lc, "OnResume");
            W($"{pauser} after wake-up: state={lc.State}, queue last told={queue}");
        }
    }
}
