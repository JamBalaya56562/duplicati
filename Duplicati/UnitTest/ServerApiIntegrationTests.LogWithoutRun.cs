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

using System.IO;
using System.Net;
using System.Threading.Tasks;
using NUnit.Framework;
using ServerProgram = Duplicati.Server.Program;

namespace Duplicati.UnitTest;

public partial class ServerApiIntegrationTests
{
    /// <summary>
    /// Showing the log of a backup that has not run yet failed with
    /// "no such table: LogData" (#1814). The log is empty instead, both when the
    /// database does not exist yet and when it exists without the table
    /// </summary>
    [Test]
    [Category("Integration")]
    public async Task TheLogOfABackupThatHasNotRunIsEmpty_Async()
    {
        await WithAuthenticatedServerAsync(async httpClient =>
        {
            var backupId = await CreateBackupAsync(httpClient, "integration-passphrase").ConfigureAwait(false);

            var provider = ServerProgram.DuplicatiWebserver.Provider;
            var connection = (Duplicati.Server.Database.Connection)provider.GetService(typeof(Duplicati.Server.Database.Connection))!;
            var dbPath = Duplicati.Server.Runner.GetEffectiveDBPath(connection.GetBackup(backupId)!);
            Assert.That(File.Exists(dbPath), Is.False, "The backup has not run, so it has no database yet");

            await AssertTheLogIsEmptyAsync().ConfigureAwait(false);

            // A database without the table, such as one that was only partly created
            Directory.CreateDirectory(Path.GetDirectoryName(dbPath)!);
            using (var con = Library.SQLiteHelper.SQLiteLoader.LoadConnection(dbPath))
            using (var cmd = con.CreateCommand())
            {
                cmd.CommandText = @"CREATE TABLE ""Other"" (""ID"" INTEGER)";
                cmd.ExecuteNonQuery();
            }

            await AssertTheLogIsEmptyAsync().ConfigureAwait(false);

            async Task AssertTheLogIsEmptyAsync()
            {
                var response = await httpClient.GetAsync($"/api/v1/backup/{backupId}/log?pagesize=25").ConfigureAwait(false);
                var content = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK), content);
                Assert.That(content.Trim(), Is.EqualTo("[]"));
            }
        }).ConfigureAwait(false);
    }
}
