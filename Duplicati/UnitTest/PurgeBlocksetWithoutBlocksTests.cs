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

using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using Duplicati.Library.Main.Database;
using Duplicati.Library.SQLiteHelper;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A file whose blockset has a length but no blocks makes every backup stop with "Found
/// inconsistency in the following files while validating database", and repair does not fix
/// it (#3085). list-broken-files reports such a file, and purge-broken-files removes it, so
/// the next backup runs again.
/// </summary>
public class PurgeBlocksetWithoutBlocksTests : BasicSetupHelper
{
    [Test]
    [Category("Targeted")]
    public async Task PurgeBrokenFilesRemovesAFileWhoseBlocksetHasNoBlocksAsync()
    {
        var options = new Dictionary<string, string>(TestOptions);

        File.WriteAllText(Path.Combine(DATAFOLDER, "small.txt"), "some data");

        // Comfortably more than the test blocksize, so the blockset spans blocks and has
        // blocklist hashes
        var large = new byte[512 * 1024];
        new System.Random(42).NextBytes(large);
        var largePath = Path.Combine(DATAFOLDER, "large.bin");
        File.WriteAllBytes(largePath, large);

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        // Remove the blocks of the large file, as the reports in the issue had them
        await using (var con = await SQLiteLoader.LoadConnectionAsync(options["dbpath"]))
        await using (var cmd = con.CreateCommand())
        {
            var id = cmd.ExecuteScalarInt64(@"
                SELECT ""BlocksetID""
                FROM ""BlocksetEntry""
                GROUP BY ""BlocksetID""
                HAVING COUNT(*) > 1
                ORDER BY COUNT(*) DESC
                LIMIT 1
            ", -1);
            Assert.That(id, Is.GreaterThanOrEqualTo(0), "The backup left no blockset with more than one block");

            foreach (var table in new[] { "BlocksetEntry", "BlocklistHash" })
                await cmd
                    .SetCommandAndParameters($@"DELETE FROM ""{table}"" WHERE ""BlocksetID"" = @Id")
                    .SetParameterValue("@Id", id)
                    .ExecuteNonQueryAsync();
        }

        // Change the small file so the next backup has something to store
        File.WriteAllText(Path.Combine(DATAFOLDER, "small.txt"), "some other data");

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            Assert.ThrowsAsync<DatabaseInconsistencyException>(async () => await c.BackupAsync([DATAFOLDER]),
                "The damage should stop the backup, as in the issue");

            var broken = await c.ListBrokenFilesAsync(null);
            var paths = (broken.BrokenFiles ?? []).SelectMany(x => x.Item3).Select(x => x.Item1).ToList();
            Assert.That(paths, Is.EqualTo(new[] { largePath }), "Only the file without blocks should be reported");

            TestUtils.AssertResults(await c.PurgeBrokenFilesAsync(null));
            Assert.That(((await c.ListBrokenFilesAsync(null)).BrokenFiles ?? []).SelectMany(x => x.Item3), Is.Empty,
                "Nothing should be broken after the purge");

            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));
        }

        // The file was purged from the old version and backed up again in the new one
        using (var c = new Controller("file://" + TARGETFOLDER, new Dictionary<string, string>(options) { ["restore-path"] = RESTOREFOLDER }, null))
            TestUtils.AssertResults(await c.RestoreAsync([largePath]));
        Assert.That(File.ReadAllBytes(Path.Combine(RESTOREFOLDER, "large.bin")), Is.EqualTo(large));
    }
}
