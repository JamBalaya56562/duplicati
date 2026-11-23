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
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Server.Database;
using Duplicati.Server.Serialization.Interface;
using Duplicati.WebserverCore.Services;
using NUnit.Framework;
using Assert = NUnit.Framework.Legacy.ClassicAssert;

namespace Duplicati.UnitTest
{
    /// <summary>
    /// https://github.com/duplicati/duplicati/issues/2654
    /// Opening the restore page while the backup ran made the listing open the same local
    /// database, and the user got SQLite's "database is locked". The server now keeps a lock per
    /// database for the running task, and an immediate task such as the restore listing fails at
    /// once with <see cref="DatabaseLockedException"/> while that lock is held.
    /// </summary>
    [Category("Targeted")]
    public class QueueRunnerServiceDatabaseLockTests
    {
        private const string DbPath = "/backups/issue2654.sqlite";

        private static Backup CreateBackup()
        {
            var backup = new Backup
            {
                ID = "1",
                Name = "Issue 2654",
                Description = "",
                Tags = [],
                TargetURL = "file:///test",
                Sources = [],
                Settings = [],
                Filters = [],
                Metadata = new Dictionary<string, string>()
            };
            backup.SetDBPath(DbPath);
            return backup;
        }

        [Test]
        public async Task ListingForRestoreFailsAtOnceWhileTheBackupHoldsTheDatabaseAsync()
        {
            var tracker = new DatabaseLockTracker();
            // The lock the queue runner takes for the running backup
            await using var backupLock = await tracker.AcquireAsync(DbPath, default);

            // Only the lock tracker is used before the task would run
            var queueRunner = new QueueRunnerService(null!, null!, null!, null!, null!, tracker, null!);

            // The listing the restore page starts
            var listing = queueRunner.RunImmediatelyAsync(
                Duplicati.Server.Runner.CreateListTask(CreateBackup(), null, false, false, false, DateTime.UtcNow));

            // Waiting for the backup to finish would hang here
            var finished = await Task.WhenAny(listing, Task.Delay(TimeSpan.FromSeconds(30)));
            Assert.AreSame(listing, finished, "The listing waited for the running backup");

            var ex = Assert.ThrowsAsync<DatabaseLockedException>(() => listing);
            Assert.AreEqual(DbPath, ex!.DatabasePath);

            // The running backup keeps its lock
            Assert.IsNull(tracker.TryAcquire(DbPath));
        }
    }
}
