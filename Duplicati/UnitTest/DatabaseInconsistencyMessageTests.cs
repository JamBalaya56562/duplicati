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
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using Duplicati.Library.SQLiteHelper;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A backup that failed on a database inconsistency used to report only "One or more errors
/// occurred", the message of the exception that wrapped the real one (#3286). The backup now
/// fails with the inconsistency itself, which names the file and says what to run.
/// </summary>
public class DatabaseInconsistencyMessageTests : BasicSetupHelper
{
    [Test]
    [Category("Targeted")]
    public async Task ABackupStoppedByAnInconsistencyReportsWhatIsWrongAsync()
    {
        var options = new Dictionary<string, string>(TestOptions) { ["no-encryption"] = "true" };
        var file = Path.Combine(DATAFOLDER, "file.bin");
        File.WriteAllBytes(file, new byte[2900]);

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        // The database says the file is empty, while its blocks say otherwise
        using (var db = await SQLiteLoader.LoadConnectionAsync(DBFILE))
        using (var cmd = db.CreateCommand())
        {
            cmd.CommandText = @"UPDATE ""Blockset"" SET ""Length"" = 0 WHERE ""Length"" = 2900";
            Assert.That(await cmd.ExecuteNonQueryAsync(), Is.EqualTo(1));
        }

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            // The exact type, not an exception that wraps it
            var ex = Assert.ThrowsAsync<DatabaseInconsistencyException>(() => c.BackupAsync([DATAFOLDER]));
            Assert.That(ex!.Message, Does.Contain("Found inconsistency in the following files"));
            Assert.That(ex.Message, Does.Contain("file.bin"));
            Assert.That(ex.Message, Does.Contain("repair"));
        }
    }
}
