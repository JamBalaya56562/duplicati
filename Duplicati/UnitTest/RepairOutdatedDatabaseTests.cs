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
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A machine that is restored to an earlier state also gets its earlier local database back.
/// Repairing with that database used to treat the newer remote files as extra and delete them,
/// so the backup was damaged for good (#3223).
/// </summary>
public class RepairOutdatedDatabaseTests : BasicSetupHelper
{
    [Test]
    [Category("Targeted")]
    public async Task RepairWithAnOutdatedDatabaseStopsWithoutTouchingTheDestinationAsync()
    {
        var options = TestOptions;
        File.WriteAllText(Path.Combine(DATAFOLDER, "a.txt"), "first");
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        // The database as it was after the first backup
        var oldDatabase = Path.Combine(BASEFOLDER, "outdated.sqlite");
        File.Copy(DBFILE, oldDatabase, true);

        // Remote file names have a resolution of one second
        await Task.Delay(2000);
        File.WriteAllText(Path.Combine(DATAFOLDER, "b.txt"), "second");
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        var remoteFiles = RemoteFiles();
        File.Copy(oldDatabase, DBFILE, true);

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            var ex = Assert.ThrowsAsync<UserInformationException>(() => c.RepairAsync());
            Assert.That(ex!.HelpID, Is.EqualTo("RemoteFilesNewerThanLocalDatabase"));
        }

        Assert.That(RemoteFiles(), Is.EquivalentTo(remoteFiles), "The repair changed the destination");
    }

    private List<string> RemoteFiles()
        => Directory.EnumerateFiles(TARGETFOLDER).Select(Path.GetFileName).Select(x => x!).ToList();
}
