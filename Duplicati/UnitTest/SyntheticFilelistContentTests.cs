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
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// The backup after an interrupted one uploads a synthetic dlist for the interrupted backup,
/// with the files of the interrupted backup.
/// </summary>
public class SyntheticFilelistContentTests : BasicSetupHelper
{
    private Dictionary<string, string> Options => TestOptions.Expand(new { no_encryption = true });

    private string[] DlistFiles
        => Directory.GetFiles(TARGETFOLDER, "*.dlist.*", SearchOption.TopDirectoryOnly)
            .Select(x => Path.GetFileName(x))
            .OrderBy(x => x, StringComparer.Ordinal)
            .ToArray();

    private async Task<string> DescribeVersionsAsync()
    {
        using var c = new Library.Main.Controller("file://" + TARGETFOLDER, Options, null);
        var result = await c.ListAsync();
        return string.Join(" | ", result.Filesets
            .OrderBy(x => x.Version)
            .Select(x => $"v{x.Version} {x.Time.ToUniversalTime():HH:mm:ss}Z full={x.IsFullBackup} files={x.FileCount}"));
    }

    private async Task<string[]> ListFilesAsync(int version)
    {
        using var c = new Library.Main.Controller("file://" + TARGETFOLDER, Options.Expand(new { version = version.ToString() }), null);
        var result = await c.ListAsync(["*"], null);
        return (result.Files ?? []).Select(x => Path.GetFileName(x.Path)).Where(x => x.Length > 0).ToArray();
    }

    /// <summary>
    /// With no retries, the interrupted backup's dlist keeps the name of its fileset time.
    /// With one retry, the dlist is renamed one second later and the name of the fileset
    /// time is left free, which the synthetic dlist was given, at the same time as the
    /// interrupted fileset.
    /// </summary>
    [Test]
    [Category("Targeted")]
    [TestCase(0)]
    [TestCase(1)]
    public async Task SyntheticFilelistHasTheFilesOfTheInterruptedBackupAsync(int interruptedRetries)
    {
        File.WriteAllText(Path.Combine(DATAFOLDER, "a.txt"), "a");
        Library.DynamicLoader.BackendLoader.AddBackend(new DeterministicErrorBackend());
        var target = new DeterministicErrorBackend().ProtocolKey + "://" + TARGETFOLDER;
        DeterministicErrorBackend.ErrorGenerator = (action, remotename)
            => action == DeterministicErrorBackend.BackendAction.PutBefore && remotename.Contains(".dlist.", StringComparison.Ordinal);
        try
        {
            using var c = new Library.Main.Controller(target, new Dictionary<string, string>(Options) { ["number-of-retries"] = interruptedRetries.ToString(), ["retry-delay"] = "0s" }, null);
            Assert.ThrowsAsync<DeterministicErrorBackend.DeterministicErrorBackendException>(async () => await c.BackupAsync([DATAFOLDER]));
        }
        finally
        {
            DeterministicErrorBackend.ErrorGenerator = null;
        }
        Thread.Sleep(3100);

        using (var c = new Library.Main.Controller("file://" + TARGETFOLDER, Options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        // The synthetic version and the new backup
        var report = $"dlist: {string.Join(", ", DlistFiles)}{Environment.NewLine}versions: {await DescribeVersionsAsync()}";
        Assert.That(await ListFilesAsync(1), Is.EqualTo(new[] { "a.txt" }), report);

        File.Delete(DBFILE);
        using (var c = new Library.Main.Controller("file://" + TARGETFOLDER, Options, null))
            TestUtils.AssertResults(await c.RepairAsync());
        report += $"{Environment.NewLine}recreated: {await DescribeVersionsAsync()}";
        Assert.That(await ListFilesAsync(1), Is.EqualTo(new[] { "a.txt" }), report);
    }
}
