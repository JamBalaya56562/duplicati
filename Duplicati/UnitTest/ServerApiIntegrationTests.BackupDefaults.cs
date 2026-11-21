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

using System.Linq;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

public partial class ServerApiIntegrationTests
{
    /// <summary>
    /// The defaults for a new backup come from a resource embedded in the server.
    /// When the resource could not be found, the error was only logged, and a new
    /// backup started without encryption and without a schedule (#4554)
    /// </summary>
    [Test]
    [Category("Integration")]
    public async Task BackupDefaultsIncludeTheBuiltInDefaults_Async()
    {
        await WithAuthenticatedServerAsync(async httpClient =>
        {
            var response = await httpClient.GetAsync("/api/v1/backupdefaults").ConfigureAwait(false);
            var content = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            var defaults = JsonNode.Parse(content)!;
            var settings = defaults["Backup"]?["Settings"]?.AsArray()
                .Select(n => (Name: (string?)n?["Name"], Value: (string?)n?["Value"]))
                .ToArray();

            Assert.That(settings, Is.Not.Null, content);
            Assert.That(settings, Does.Contain(("encryption-module", (string?)"aes")), content);
            Assert.That((string?)defaults["Schedule"]?["Repeat"], Is.EqualTo("1D"), content);
        }).ConfigureAwait(false);
    }
}
