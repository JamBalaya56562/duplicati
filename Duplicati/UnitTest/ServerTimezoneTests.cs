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
using System.Collections.Generic;
using System.IO;
using System.Threading;
using Duplicati.Library.Interface;
using Duplicati.Server;
using Duplicati.WebserverCore.Abstractions;
using NUnit.Framework;
using Program = Duplicati.Server.Program;

namespace Duplicati.UnitTest;

/// <summary>
/// Schedules keep their time of day across a daylight saving change in the server time zone
/// (#1364), but a server without --server-timezone used UTC. Nothing sets that option on a new
/// install and ngclient has no setting for it, so daily jobs ran an hour early once daylight
/// saving ended (forum 22834), while the old UI showed the local time zone as if it were set.
/// </summary>
public class ServerTimezoneTests
{
    private sealed class TestApplicationSettings(string dataFolder) : IApplicationSettings
    {
        public Action? StartOrStopUsageReporter { get; set; }
        public string DataFolder => dataFolder;
        public string Origin { get; set; } = "UnitTest";
        public CancellationToken ApplicationExit => CancellationToken.None;
        public void SignalApplicationExit() { }
        public ISecretProvider? SecretProvider { get; set; }
        public ISecretProvider? DefaultSecretProvider { get; set; }
        public bool SettingsEncryptionKeyProvidedExternally { get; set; }
    }

    [Test]
    public void AnUnsetTimezoneIsTheLocalOne()
    {
        var dataFolder = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(dataFolder);
        try
        {
            var options = new Dictionary<string, string> { { "disable-default-secret-provider", "true" } };
            using var connection = Program.GetDatabaseConnection(new TestApplicationSettings(dataFolder), options, true, false);

            Assert.That(connection.ApplicationSettings.Timezone, Is.EqualTo(TimeZoneInfo.Local));
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            try { Directory.Delete(dataFolder, true); } catch { }
        }
    }

    /// <summary>
    /// What the time zone does for a daily backup at 01:00 in Luxembourg, around the end of
    /// daylight saving on 2026-10-25
    /// </summary>
    [Test]
    public void ADailyScheduleKeepsItsLocalTimeWhenDaylightSavingEnds()
    {
        var luxembourg = TimeZoneInfo.FindSystemTimeZoneById("Europe/Luxembourg");

        // The run on 2026-10-25 at 01:00, still summer time; the scheduler then asks for the next
        // time after it, as it does once a run has started
        var run = new DateTime(2026, 10, 24, 23, 0, 0, DateTimeKind.Utc);

        var inLuxembourg = Scheduler.GetNextValidTime(run, run.AddSeconds(1), "1D", [], luxembourg);
        Assert.That(TimeZoneInfo.ConvertTimeFromUtc(inLuxembourg, luxembourg), Is.EqualTo(new DateTime(2026, 10, 26, 1, 0, 0)));

        // In UTC the backup moves to 00:00 winter time, as reported
        var inUtc = Scheduler.GetNextValidTime(run, run.AddSeconds(1), "1D", [], TimeZoneInfo.Utc);
        Assert.That(TimeZoneInfo.ConvertTimeFromUtc(inUtc, luxembourg), Is.EqualTo(new DateTime(2026, 10, 26, 0, 0, 0)));
    }
}
