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
using System.Runtime.Versioning;
using System.Security.Principal;
using Duplicati.Library.Snapshots;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// Probe for #7005 and #6866: a snapshot that fails after the snapshot set was started leaves
/// it in progress, and the next snapshot in the same process fails with 0x80042316.
/// Needs an elevated process. Run one provider per process.
/// </summary>
[TestFixture]
[Explicit("Probe, needs an elevated process")]
[Category("VssProbe")]
public class VssFailedSnapshotProbe
{
    private static void Log(string message)
        => TestContext.Progress.WriteLine($"PROBEVSS {DateTime.Now:HH:mm:ss.fff} {message}");

    [TestCase("Native")]
    [TestCase("Vanara")]
    [TestCase("AlphaVSS")]
    public void ASnapshotAfterAFailedOneWorks(string provider)
    {
        if (!OperatingSystem.IsWindows())
            Assert.Ignore("VSS is Windows only");
        if (!IsElevated())
            Assert.Ignore("VSS needs an elevated process");

        var local = Path.Combine(Path.GetTempPath(), "vss-probe");
        Directory.CreateDirectory(local);
        File.WriteAllText(Path.Combine(local, "file.txt"), "probe");
        var localSource = local + Path.DirectorySeparatorChar;

        // A source that VSS cannot snapshot. It is checked after the snapshot set is started.
        var unsupported = Environment.GetEnvironmentVariable("VSS_PROBE_UNSUPPORTED") ?? @"\\localhost\C$\Windows\Temp\";
        var options = new Dictionary<string, string> { ["snapshot-provider"] = provider };
        Log($"provider={provider} local={localSource} unsupported={unsupported}");

        // 1. A snapshot that fails
        try
        {
            using var first = new WindowsSnapshot(new[] { localSource, unsupported }, options, false);
            Log("first snapshot SUCCEEDED (the unsupported source did not make it fail; pick another one with VSS_PROBE_UNSUPPORTED)");
            Assert.Inconclusive("The first snapshot did not fail");
        }
        catch (Exception ex) when (ex is not InconclusiveException)
        {
            Log($"first snapshot failed as intended: {ex.GetType().Name}: {ex.Message} (HResult 0x{ex.HResult:X8})");
        }

        // 2. A snapshot of a supported folder, in the same process
        try
        {
            using var second = new WindowsSnapshot(new[] { localSource }, options, false);
            Log("second snapshot SUCCEEDED");
        }
        catch (Exception ex)
        {
            Log($"second snapshot FAILED: {ex.GetType().Name}: {ex.Message} (HResult 0x{ex.HResult:X8})");
            foreach (var line in (ex.StackTrace ?? "").Split('\n'))
                Log($"  stack: {line.Trim()}");
            for (var inner = ex.InnerException; inner != null; inner = inner.InnerException)
                Log($"  inner: {inner.GetType().Name}: {inner.Message} (HResult 0x{inner.HResult:X8})");
            throw;
        }
    }

    /// <summary>
    /// Control: two snapshots in a row, with no failure in between, in the same process
    /// </summary>
    [TestCase("Native")]
    public void TwoSnapshotsInARowWork(string provider)
    {
        if (!OperatingSystem.IsWindows())
            Assert.Ignore("VSS is Windows only");
        if (!IsElevated())
            Assert.Ignore("VSS needs an elevated process");

        var local = Path.Combine(Path.GetTempPath(), "vss-probe");
        Directory.CreateDirectory(local);
        File.WriteAllText(Path.Combine(local, "file.txt"), "probe");
        var localSource = local + Path.DirectorySeparatorChar;
        var options = new Dictionary<string, string> { ["snapshot-provider"] = provider };

        for (var i = 1; i <= 2; i++)
        {
            try
            {
                using var snapshot = new WindowsSnapshot(new[] { localSource }, options, false);
                Log($"control provider={provider} snapshot {i} SUCCEEDED");
            }
            catch (Exception ex)
            {
                Log($"control provider={provider} snapshot {i} FAILED: {ex.GetType().Name}: {ex.Message} (HResult 0x{ex.HResult:X8})");
                throw;
            }
        }
    }

    [SupportedOSPlatform("windows")]
    private static bool IsElevatedWindows()
        => new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);

    private static bool IsElevated()
        => OperatingSystem.IsWindows() && IsElevatedWindows();
}
