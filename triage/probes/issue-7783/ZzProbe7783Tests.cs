using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Temporary probe for #7783, not to be committed.
[TestFixture]
public class ZzProbe7783Tests : BasicSetupHelper
{
    private static string MakeSource(string root, string name)
    {
        var dir = Path.Combine(root, name);
        if (Directory.Exists(dir)) Directory.Delete(dir, true);
        Directory.CreateDirectory(Path.Combine(dir, "sub"));
        File.WriteAllText(Path.Combine(dir, "a.txt"), "a " + name);
        File.WriteAllText(Path.Combine(dir, "sub", "b.txt"), "b " + name);
        return dir;
    }

    private static string Remote(string dir, string mountName)
        => "@" + Path.Combine(Path.GetPathRoot(dir)!, "zz-virtual-7783", mountName) + "|file://" + dir.Replace('\\', '/') + "?auth-username=probe";

    private async Task Run(string label, string[] sources, string target)
    {
        if (Directory.Exists(target)) Directory.Delete(target, true);
        Directory.CreateDirectory(target);
        var opts = new Dictionary<string, string> { ["no-encryption"] = "true", ["snapshot-policy"] = "off" };
        using var c = new Controller("file://" + target.Replace('\\', '/'), opts, null);
        try
        {
            var res = await c.SyncAsync(sources, null);
            TestContext.Progress.WriteLine($"PROBE7783 {label}: uploaded={res.FilesUploaded} warnings=[{string.Join(" | ", res.Warnings)}] errors=[{string.Join(" | ", res.Errors)}]");
        }
        catch (Exception ex) { TestContext.Progress.WriteLine($"PROBE7783 {label}: THROWS {ex.GetType().Name}: {ex.Message}"); }
        foreach (var f in Directory.GetFileSystemEntries(target, "*", SearchOption.AllDirectories).OrderBy(x => x))
            TestContext.Progress.WriteLine($"PROBE7783 {label}:   {Path.GetRelativePath(target, f)}");
    }

    [Test]
    public async Task Probe()
    {
        var a = MakeSource(BASEFOLDER, "src-a");
        var b = MakeSource(BASEFOLDER, "src-b");
        await Run("local-single", [a], Path.Combine(BASEFOLDER, "t1"));
        await Run("remote-single", [Remote(a, "music")], Path.Combine(BASEFOLDER, "t2"));
        await Run("local-two", [a, b], Path.Combine(BASEFOLDER, "t0"));
        await Run("remote-plus-local", [Remote(a, "music"), b], Path.Combine(BASEFOLDER, "t3"));
        await Run("remote-two", [Remote(a, "music"), Remote(b, "docs")], Path.Combine(BASEFOLDER, "t4"));

        // A backup with the same remote source, for comparison
        var bt = Path.Combine(BASEFOLDER, "bt");
        if (Directory.Exists(bt)) Directory.Delete(bt, true);
        Directory.CreateDirectory(bt);
        var opts = new Dictionary<string, string> { ["no-encryption"] = "true", ["dbpath"] = Path.Combine(BASEFOLDER, "zz7783.sqlite") };
        using (var c = new Controller("file://" + bt.Replace('\\', '/'), opts, null))
        {
            var res = await c.BackupAsync([Remote(a, "music")]);
            TestContext.Progress.WriteLine($"PROBE7783 backup: added={res.AddedFiles} examined={res.ExaminedFiles} warnings=[{string.Join(" | ", res.Warnings)}]");
        }
    }
}
