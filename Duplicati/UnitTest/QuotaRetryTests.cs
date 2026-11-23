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
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.DynamicLoader;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// Reading the quota was a single request outside the retry handling, so one failed request,
/// such as the 404 OneDrive sometimes returned, failed the whole backup (#4015).
/// </summary>
public class QuotaRetryTests : BasicSetupHelper
{
    /// <summary>
    /// A destination whose first quota request fails.
    /// </summary>
    private sealed class FlakyQuotaBackend : NoFreeSpaceBackend
    {
        private const long Space = 4_000_000_000_000;

        public static int Calls;

        public FlakyQuotaBackend()
        {
        }

        public FlakyQuotaBackend(string url, Dictionary<string, string> options)
            : base(url, options)
        {
        }

        public override string ProtocolKey => "flakyquota";

        public override Task<IQuotaInfo?> GetQuotaInfoAsync(CancellationToken cancelToken)
        {
            if (Interlocked.Increment(ref Calls) == 1)
                throw new HttpRequestException("Not Found", null, HttpStatusCode.NotFound);
            return Task.FromResult<IQuotaInfo?>(new QuotaInfo(Space, Space));
        }
    }

    [SetUp]
    public void RegisterBackend()
    {
        NoFreeSpaceBackend.Folder = TARGETFOLDER;
        FlakyQuotaBackend.Calls = 0;
        BackendLoader.AddBackend(new FlakyQuotaBackend());
    }

    [Test]
    [Category("Quota")]
    public async Task AFailedQuotaRequestIsRetriedAsync()
    {
        File.WriteAllText(Path.Combine(DATAFOLDER, "file.txt"), "some data");
        var options = TestOptions.Expand(new { no_encryption = true, number_of_retries = 2, retry_delay = "0s" });

        using (var c = new Controller("flakyquota://destination", options, null))
        {
            var results = await c.BackupAsync([DATAFOLDER]);
            Assert.That(results.Errors, Is.Empty, string.Join("\n", results.Errors));
            Assert.That(results.ParsedResult, Is.Not.EqualTo(ParsedResultType.Error));
        }

        Assert.That(FlakyQuotaBackend.Calls, Is.GreaterThan(1), "The failed quota request was not tried again");
        Assert.That(Directory.EnumerateFiles(TARGETFOLDER, "*.dlist.*").Count(), Is.EqualTo(1));
    }
}
