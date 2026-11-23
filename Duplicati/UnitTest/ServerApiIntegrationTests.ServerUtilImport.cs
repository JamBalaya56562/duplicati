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
using System.Net.Http;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// <c>duplicati-server-util import</c> replaced the ConfigurationImporter tool, which was to be
/// checked after the move from .NET Framework (#4540). This imports an exported configuration with
/// the connection the tool uses, against a running server.
/// </summary>
public partial class ServerApiIntegrationTests
{
    [Test]
    [Category("Integration")]
    public async Task ServerUtilImportsAnExportedConfiguration_Async()
    {
        await WithAuthenticatedServerAsync(async httpClient =>
        {
            var backupId = await CreateBackupAsync(httpClient, "integration-passphrase", backupName: "ServerUtil import source").ConfigureAwait(false);
            var exportFile = Path.Combine(BASEFOLDER, "serverutil-import.json");
            await File.WriteAllBytesAsync(exportFile, await ExportConfigurationAsync(httpClient, backupId).ConfigureAwait(false)).ConfigureAwait(false);

            using var toolClient = new HttpClient { BaseAddress = new Uri(httpClient.BaseAddress!, "/api/v1/") };
            toolClient.DefaultRequestHeaders.Authorization = httpClient.DefaultRequestHeaders.Authorization;
            var connection = new CommandLine.ServerUtil.Connection(toolClient);

            var imported = await connection.ImportBackupAsync(exportFile, null, false, new Dictionary<string, string>()).ConfigureAwait(false);

            Assert.That(imported.ID, Is.Not.EqualTo(backupId), "The import made a new backup");
            // The server adds a number to a name that is already taken
            Assert.That(imported.Name, Does.StartWith("ServerUtil import source"));
            await AssertBackupListedAsync(httpClient, imported.ID, imported.Name).ConfigureAwait(false);
        }).ConfigureAwait(false);
    }
}
