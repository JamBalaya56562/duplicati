// Copyright (C) 2026, The Duplicati Team
// https://duplicati.com, hello@duplicati.com
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

#nullable enable

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.AutoUpdater;
using Duplicati.Library.Interface;
using Duplicati.Library.RestAPI.Database;
using Duplicati.Library.SQLiteHelper;
using Duplicati.Server;
using Duplicati.Server.Database;
using Duplicati.Server.Serialization.Interface;
using Duplicati.WebserverCore.Abstractions;
using NUnit.Framework;
using Assert = NUnit.Framework.Legacy.ClassicAssert;
using CollectionAssert = NUnit.Framework.Legacy.CollectionAssert;

namespace Duplicati.UnitTest;

/// <summary>
/// A schedule that is edited after the backup has run keeps its next run (issue #1226).
/// The old UI showed the next run a day early after an edit, and once that date was saved
/// the scheduler did not run the backup until Duplicati was restarted. The old UI now shows
/// and saves the next run that the server reports, and the scheduler moves a start time
/// in the past on to the next slot after the last run.
/// </summary>
[TestFixture]
[Category("Scheduler")]
public class SchedulerEditedScheduleTests
{
    private string _tempDataFolder = null!;
    private Connection _connection = null!;

    /// <summary>
    /// Queue runner that records the tasks the scheduler adds
    /// </summary>
    private sealed class RecordingQueueRunnerService : IQueueRunnerService
    {
        public ConcurrentQueue<IQueuedTask> Added { get; } = new();
        public ManualResetEventSlim TaskAdded { get; } = new(false);

        public IQueuedTask? GetCurrentTask() => null;
        public List<IQueuedTask> GetCurrentTasks() => new();
        public bool GetIsActive() => false;
        public CachedTaskResult? GetCachedTaskResults(long taskID) => null;
        public long AddTask(IQueuedTask task) => AddTask(task, false);
        public long AddTask(IQueuedTask task, bool skipQueue)
        {
            Added.Enqueue(task);
            TaskAdded.Set();
            return Added.Count;
        }
        public void Terminate(bool wait) { }
        public void Resume() { }
        public void Pause() { }
        public IList<Tuple<long, string?>> GetQueueWithIds() => new List<Tuple<long, string?>>();
        public void CancelCurrentTaskLockWait(long taskID) { }
        public Task<IBasicResults?> RunImmediatelyAsync(IQueuedTask task) => Task.FromResult<IBasicResults?>(null);
    }

    [SetUp]
    public async Task SetUpAsync()
    {
        _tempDataFolder = Path.Combine(Path.GetTempPath(), $"duplicati-scheduler-edited-test-{Guid.NewGuid()}");
        Directory.CreateDirectory(_tempDataFolder);

        var databasePath = Path.Combine(_tempDataFolder, DataFolderManager.SERVER_DATABASE_FILENAME);
        var dbConnection = await SQLiteLoader.LoadConnectionAsync(databasePath);
        DatabaseUpgrader.UpgradeDatabase(dbConnection, databasePath, typeof(DatabaseSchemaMarker));
        _connection = new Connection(dbConnection, true, null, _tempDataFolder, () => { });
    }

    [TearDown]
    public void TearDown()
    {
        _connection?.Dispose();
        try
        {
            if (Directory.Exists(_tempDataFolder))
                Directory.Delete(_tempDataFolder, true);
        }
        catch
        {
            // Best effort cleanup
        }
    }

    /// <summary>
    /// Builds a minimal backup that passes validation
    /// </summary>
    private static Backup BuildBackup(string name, bool skipMissed)
    {
        var settings = new List<ISetting> { new Setting { Name = "passphrase", Value = "secret", Filter = string.Empty } };
        if (skipMissed)
            settings.Add(new Setting { Name = "--skip-missed-scheduled-backups", Value = "true", Filter = string.Empty });

        return new Backup
        {
            Name = name,
            Description = "Edited schedule test",
            Tags = Array.Empty<string>(),
            TargetURL = "file:///mock_edited_target",
            Sources = new[] { "Mock Source" },
            Settings = settings.ToArray(),
            Filters = Array.Empty<IFilter>(),
            Metadata = new Dictionary<string, string>(),
        };
    }

    private IBackup Save(Backup backup, ISchedule schedule)
    {
        _connection.AddOrUpdateBackupAndSchedule(backup, schedule);
        return backup;
    }

    /// <summary>
    /// Runs one scheduler pass and returns the IDs of the queued backups and the proposed schedule
    /// </summary>
    private (string?[] Queued, IList<Tuple<string, DateTime>> Proposed) RunSchedulerPass()
    {
        var queue = new RecordingQueueRunnerService();
        var scheduler = new Scheduler(_connection, queue);
        try
        {
            scheduler.Reschedule();
            Assert.IsTrue(queue.TaskAdded.Wait(TimeSpan.FromSeconds(30)),
                "The scheduler should queue at least one due backup.");
        }
        finally
        {
            // Terminating waits for the scheduler pass to finish, so every task it queues is recorded
            scheduler.Terminate(true);
        }

        return (queue.Added.Select(x => x.BackupID).ToArray(), scheduler.GetProposedSchedule());
    }

    /// <summary>
    /// Runs one scheduler pass without requiring that anything is queued
    /// </summary>
    private (string?[] Queued, IList<Tuple<string, DateTime>> Proposed) RunSchedulerPassAllowingNone()
    {
        var queue = new RecordingQueueRunnerService();
        var scheduler = new Scheduler(_connection, queue);
        try
        {
            scheduler.Reschedule();
            queue.TaskAdded.Wait(TimeSpan.FromSeconds(3));
        }
        finally
        {
            scheduler.Terminate(true);
        }

        return (queue.Added.Select(x => x.BackupID).ToArray(), scheduler.GetProposedSchedule());
    }

    /// <summary>
    /// Builds an hourly schedule as the old UI saved it after an edit: the time of the next
    /// run with the date of the day before, for a backup whose last run started a little after
    /// its slot, as a scheduled run does
    /// </summary>
    private static (Schedule Schedule, DateTime NextSlot) BuildEditedHourlySchedule(DateTime lastSlot)
    {
        var nextSlot = lastSlot.AddHours(1);
        return (new Schedule
        {
            Tags = Array.Empty<string>(),
            Time = nextSlot.AddDays(-1),
            Repeat = "1h",
            LastRun = lastSlot.AddSeconds(25),
            Rule = string.Empty,
        }, nextSlot);
    }

    /// <summary>
    /// A slot the given time ago, on a whole minute as the UI saves it
    /// </summary>
    private static DateTime SlotAgo(TimeSpan ago)
    {
        var t = DateTime.UtcNow - ago;
        return new DateTime(t.Year, t.Month, t.Day, t.Hour, t.Minute, 0, DateTimeKind.Utc);
    }

    [Test]
    public void EditedScheduleWithAnEarlierDate_ProposesTheNextSlotAfterTheLastRun()
    {
        var (schedule, nextSlot) = BuildEditedHourlySchedule(SlotAgo(TimeSpan.FromMinutes(20)));
        var backup = Save(BuildBackup("edited-not-due", skipMissed: false), schedule);

        var (queued, proposed) = RunSchedulerPassAllowingNone();

        CollectionAssert.IsEmpty(queued, "The backup ran 20 minutes ago, so its next hourly slot is not due yet.");
        var next = proposed.Single(x => x.Item1 == backup.ID).Item2;
        Assert.AreEqual(nextSlot, next, "The next run should be the hourly slot after the last run, not a day earlier or later.");
    }

    [Test]
    public void EditedScheduleWithAnEarlierDate_RunsWhenTheSlotIsDue()
    {
        var (schedule, nextSlot) = BuildEditedHourlySchedule(SlotAgo(TimeSpan.FromMinutes(70)));
        var backup = Save(BuildBackup("edited-due", skipMissed: false), schedule);

        var (queued, proposed) = RunSchedulerPass();

        CollectionAssert.AreEqual(new[] { backup.ID }, queued, "The hourly slot after the last run has passed, so the backup should run.");
        var next = proposed.Single(x => x.Item1 == backup.ID).Item2;
        Assert.AreEqual(nextSlot.AddHours(1), next, "After the run is queued, the next run should be the following hourly slot.");
    }
}
