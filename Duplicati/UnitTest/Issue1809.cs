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
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.DynamicLoader;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A check of all the dlist and dindex files that does not download the
/// dblock files was requested in #1809. It is --full-remote-verification=ListAndIndexes
/// </summary>
public class Issue1809 : BasicSetupHelper
{
    [Test]
    [Category("Targeted")]
    public async Task ListAndIndexesChecksEveryListAndIndexWithoutTheBlocksAsync()
    {
        var rnd = new Random(1809);
        for (var i = 0; i < 3; i++)
        {
            var data = new byte[1024 * 1024];
            rnd.NextBytes(data);
            File.WriteAllBytes(Path.Combine(DATAFOLDER, $"a{i}"), data);
        }

        var opts = TestOptions;
        opts["dblock-size"] = "1mb";
        using (var c = new Controller("file://" + TARGETFOLDER, opts, null))
            TestUtils.AssertResults(await c.BackupAsync(new[] { DATAFOLDER }));

        var remote = Directory.GetFiles(TARGETFOLDER).Select(Path.GetFileName).ToArray();
        Assert.That(remote.Count(x => x!.Contains(".dblock.")), Is.GreaterThan(1), "The backup should have several dblock files");

        var downloaded = new ConcurrentBag<string>();
        BackendLoader.AddBackend(new DeterministicErrorBackend());
        DeterministicErrorBackend.ErrorGenerator = (action, remotename) =>
        {
            if (action == DeterministicErrorBackend.BackendAction.GetBefore)
                downloaded.Add(remotename);
            return false;
        };

        try
        {
            opts["full-remote-verification"] = nameof(Options.RemoteTestStrategy.ListAndIndexes);
            using (var c = new Controller(new DeterministicErrorBackend().ProtocolKey + "://" + TARGETFOLDER, opts, null))
                TestUtils.AssertResults(await c.TestAsync(short.MaxValue));
        }
        finally
        {
            DeterministicErrorBackend.ErrorGenerator = null;
        }

        Assert.That(downloaded.Where(x => x.Contains(".dblock.")), Is.Empty, "No dblock file should be downloaded");
        Assert.That(downloaded.Distinct(), Is.EquivalentTo(remote.Where(x => x!.Contains(".dlist.") || x!.Contains(".dindex."))),
            "Every dlist and dindex file should be checked");
    }
}
