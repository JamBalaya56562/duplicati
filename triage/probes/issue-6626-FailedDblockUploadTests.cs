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
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A backup whose data volumes fail to upload must not leave behind a backup version that
/// refers to the data that never arrived (#6626).
/// </summary>
[Category("Targeted")]
public class FailedDblockUploadTests : BasicSetupHelper
{
    [TearDown]
    public void ResetErrors() => DeterministicErrorBackend.ErrorGenerator = null;

    private static void WriteRandom(string path, int size)
    {
        var data = new byte[size];
        new Random().NextBytes(data);
        File.WriteAllBytes(path, data);
    }

    [Test]
    public Task VersionsAreRestorableAfterAFailedDblockUpload_NoRetries_Async() => RunAsync(0, false, true);

    [Test]
    public Task VersionsAreRestorableAfterAFailedDblockUpload_WithRetries_Async() => RunAsync(2, false, true);

    [Test]
    public Task VersionsAreRestorableAfterAFailedDblockUpload_NoBackendVerification_Async() => RunAsync(0, true, true);

    [Test]
    public Task VersionsAreRestorableAfterAFailedDblockUpload_Unchanged_Async() => RunAsync(0, false, false);

    [Test]
    public Task VersionsAreRestorableAfterAFailedDblockUpload_Unchanged_NoBackendVerification_Async() => RunAsync(0, true, false);

    [Test]
    public Task VersionsAreRestorableAfterAPartialDblockUpload_Async() => RunAsync(0, false, true, partial: true);

    [Test]
    public Task VersionsAreRestorableAfterAPartialDblockUpload_Unchanged_Async() => RunAsync(0, false, false, partial: true);

    private async Task RunAsync(int retries, bool noBackendVerification, bool changeAgain, bool partial = false)
    {
        var options = new Dictionary<string, string>(TestOptions)
        {
            ["no-backend-verification"] = noBackendVerification ? "true" : "false",
            ["number-of-retries"] = retries.ToString(),
            ["retry-delay"] = "1s",
            ["dblock-size"] = "1mb",
        };

        var stable = Path.Combine(DATAFOLDER, "stable.bin");
        var changing = Path.Combine(DATAFOLDER, "changing.bin");
        WriteRandom(stable, 512 * 1024);
        WriteRandom(changing, 512 * 1024);

        // 1. A complete backup
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        // 2. The file changes, and the backup of the change fails to upload its data
        WriteRandom(changing, 512 * 1024);
        Library.DynamicLoader.BackendLoader.AddBackend(new DeterministicErrorBackend());
        DeterministicErrorBackend.ErrorGenerator = (action, remotename) =>
        {
            if (!remotename.Contains(".dblock."))
                return false;
            if (!partial)
                return action == DeterministicErrorBackend.BackendAction.PutBefore;
            if (action != DeterministicErrorBackend.BackendAction.PutAfter)
                return false;

            // The connection breaks after part of the volume has reached the destination
            var remote = Path.Combine(TARGETFOLDER, remotename);
            using (var fs = new FileStream(remote, FileMode.Open, FileAccess.Write))
                fs.SetLength(fs.Length / 2);
            return true;
        };

        using (var c = new Controller(new DeterministicErrorBackend().ProtocolKey + "://" + TARGETFOLDER, options, null))
        {
            try
            {
                var failed = await c.BackupAsync([DATAFOLDER]);
                TestContext.Progress.WriteLine($"Failing backup ended with {failed.ParsedResult}: {string.Join(" | ", failed.Errors)}");
            }
            catch (Exception ex)
            {
                TestContext.Progress.WriteLine($"Failing backup threw {ex.GetType().Name}: {ex.Message}");
            }
        }
        DeterministicErrorBackend.ErrorGenerator = null;

        // 3. The next backup runs normally, with the file changed again or as it was
        if (changeAgain)
            WriteRandom(changing, 512 * 1024);
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            var res = await c.BackupAsync([DATAFOLDER]);
            TestContext.Progress.WriteLine($"Next backup: {res.ParsedResult}, warnings: {string.Join(" | ", res.Warnings)}, errors: {string.Join(" | ", res.Errors)}");
            TestUtils.AssertResults(res);
        }

        TestContext.Progress.WriteLine("Remote files: " + string.Join(", ", Directory.GetFiles(TARGETFOLDER).Select(Path.GetFileName)));

        // 4. Every version must be restorable from the remote files alone
        var recreated = Path.Combine(BASEFOLDER, "recreated-6626.sqlite");
        if (File.Exists(recreated))
            File.Delete(recreated);
        var recreateOptions = new Dictionary<string, string>(options) { ["dbpath"] = recreated };
        using (var c = new Controller("file://" + TARGETFOLDER, recreateOptions, null))
        {
            var repair = await c.RepairAsync();
            TestContext.Progress.WriteLine($"Recreate: {repair.ParsedResult}, warnings: {string.Join(" | ", repair.Warnings)}, errors: {string.Join(" | ", repair.Errors)}");
            TestUtils.AssertResults(repair);
        }

        int versions;
        using (var c = new Controller("file://" + TARGETFOLDER, recreateOptions, null))
            versions = (await c.ListFilesetsAsync()).Filesets.Count();
        TestContext.Progress.WriteLine($"Versions: {versions}");

        for (var v = 0; v < versions; v++)
        {
            var restoreFolder = Path.Combine(RESTOREFOLDER, "v" + v);
            Directory.CreateDirectory(restoreFolder);
            var restoreOptions = new Dictionary<string, string>(recreateOptions)
            {
                ["restore-path"] = restoreFolder,
                ["version"] = v.ToString(),
            };
            using var c = new Controller("file://" + TARGETFOLDER, restoreOptions, null);
            var restore = await c.RestoreAsync(null);
            TestContext.Progress.WriteLine($"Restore version {v}: {restore.ParsedResult}, warnings: {string.Join(" | ", restore.Warnings)}, errors: {string.Join(" | ", restore.Errors)}");
            TestUtils.AssertResults(restore);
        }
    }
}
