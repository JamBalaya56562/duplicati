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
/// Firefox keeps a <c>lock</c> symlink in its profile folder that points to
/// <c>host:+pid</c>, which does not exist. A profile folder with it used to stop every backup with
/// "UNIQUE constraint failed: FilesetEntry.FilesetID, FilesetEntry.FileID" (#3753).
/// </summary>
public class DanglingSymlinkBackupTests : BasicSetupHelper
{
    [Test]
    [Category("Targeted")]
    public async Task AFolderWithAFirefoxStyleLockLinkIsBackedUpRepeatedlyAsync()
    {
        var profile = Path.Combine(DATAFOLDER, "profile");
        Directory.CreateDirectory(profile);
        File.WriteAllText(Path.Combine(profile, "prefs.js"), "first");
        var lockLink = Path.Combine(profile, "lock");
        CreateLinkOrIgnore(lockLink, "127.0.1.1:+12345");
        CreateLinkOrIgnore(Path.Combine(profile, "dangling"), Path.Combine(profile, "missing"));

        var options = new Dictionary<string, string>(TestOptions) { ["no-encryption"] = "true" };
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        // A changed file next to the link
        await Task.Delay(1100);
        File.WriteAllText(Path.Combine(profile, "prefs.js"), "second");
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        // Firefox makes the link again, pointing to its new process
        await Task.Delay(1100);
        File.Delete(lockLink);
        CreateLinkOrIgnore(lockLink, "127.0.1.1:+23456");
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            TestUtils.AssertResults(await c.BackupAsync([DATAFOLDER]));

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
            Assert.That((await c.ListAsync()).Filesets.Count(), Is.EqualTo(3));

        for (var version = 0; version < 3; version++)
        {
            var versionOptions = new Dictionary<string, string>(options) { ["version"] = version.ToString() };
            using var c = new Controller("file://" + TARGETFOLDER, versionOptions, null);
            var listed = await c.ListAsync("*");
            Assert.That(listed.Files.Any(x => x.Path.EndsWith(Path.DirectorySeparatorChar + "lock", StringComparison.Ordinal)), Is.True,
                $"The lock link is missing from version {version}");
        }
    }

    private static void CreateLinkOrIgnore(string path, string target)
    {
        try
        {
            File.CreateSymbolicLink(path, target);
        }
        catch (Exception ex) when (OperatingSystem.IsWindows() && (ex is UnauthorizedAccessException or IOException))
        {
            // Windows only allows symbolic links with developer mode or the privilege for it
            Assert.Ignore("Symbolic links cannot be created here: " + ex.Message);
        }
    }
}
