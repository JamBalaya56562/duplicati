using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe: the backup source is itself a symbolic link to a folder. What does a restore to
// the original location do?
public class RootLinkProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBERL " + msg);

    private string Outside => this.DATAFOLDER.TrimEnd(Path.DirectorySeparatorChar) + "-outside";
    private string Link => Path.Combine(this.DATAFOLDER, "link");
    private string LinkSource => Link + Path.DirectorySeparatorChar;

    private static string Msgs(IBasicResults r)
        => $"errors={r.Errors.Count()} warnings={r.Warnings.Count()} {string.Join(" | ", r.Errors.Concat(r.Warnings)).Replace("\n", " ")}";

    private static string Describe(string root)
    {
        var di = new DirectoryInfo(root);
        if (di.LinkTarget != null && !Directory.Exists(Path.GetFullPath(Path.Combine(Path.GetDirectoryName(root)!, di.LinkTarget)))) return $"(dangling link -> {Path.GetFileName(di.LinkTarget)})";
        if (!Directory.Exists(root)) return "(none)";
        var head = di.LinkTarget != null ? $"[link -> {Path.GetFileName(di.LinkTarget)}] " : "[real folder] ";
        var items = Directory.EnumerateFileSystemEntries(root, "*", SearchOption.AllDirectories)
            .Select(x => x.Substring(root.TrimEnd(Path.DirectorySeparatorChar).Length) + (File.Exists(x) ? $" [{File.ReadAllText(x)}]" : Path.DirectorySeparatorChar.ToString()))
            .OrderBy(x => x, StringComparer.Ordinal);
        return head + string.Join(", ", items);
    }

    private async Task Setup()
    {
        if (Directory.Exists(Outside)) Directory.Delete(Outside, true);
        Directory.CreateDirectory(Path.Combine(Outside, "sub"));
        File.WriteAllText(Path.Combine(Outside, "a.txt"), "a");
        File.WriteAllText(Path.Combine(Outside, "sub", "b.txt"), "b");
        try { Directory.CreateSymbolicLink(Link, Outside); }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { Assert.Ignore("no symlinks: " + ex.Message); }

        using var c = new Controller("file://" + this.TARGETFOLDER, new Dictionary<string, string>(this.TestOptions), null);
        W($"backup: {Msgs(await c.BackupAsync([LinkSource]))}");
        using var c2 = new Controller("file://" + this.TARGETFOLDER, new Dictionary<string, string>(this.TestOptions), null);
        var l = await c2.ListAsync("*");
        W($"list: {string.Join(", ", l.Files.Select(x => x.Path))}");
    }

    private async Task Restore(string name, bool overwrite, string restorePath = null)
    {
        W($"{name} before: link={Describe(Link)} ; outside={Describe(Outside)}");
        var options = new Dictionary<string, string>(this.TestOptions) { ["overwrite"] = overwrite ? "true" : "false" };
        if (restorePath != null) options["restore-path"] = restorePath;
        using (var c = new Controller("file://" + this.TARGETFOLDER, options, null))
        {
            try { W($"{name} restore: {Msgs(await c.RestoreAsync(null))}"); }
            catch (Exception ex) { W($"{name} restore: EXCEPTION {ex.GetType().Name}: {ex.Message}"); }
        }
        W($"{name} after: link={Describe(Link)} ; outside={Describe(Outside)}" + (restorePath != null ? $" ; restored={Describe(restorePath)}" : ""));
    }

    // A: everything is still there; the files were changed after the backup
    [Test]
    public async Task A_Intact()
    {
        await Setup();
        File.WriteAllText(Path.Combine(Outside, "a.txt"), "changed");
        await Restore("A_Intact", true);
    }

    // B: the link is gone, what it pointed to is still there
    [Test]
    public async Task B_LinkGone()
    {
        await Setup();
        new DirectoryInfo(Link).Delete();
        await Restore("B_LinkGone", false);
    }

    // C: both are gone, as on a new machine
    [TestCase(false)]
    [TestCase(true)]
    public async Task C_BothGone(bool overwrite)
    {
        await Setup();
        new DirectoryInfo(Link).Delete();
        Directory.Delete(Outside, true);
        await Restore($"C_BothGone(overwrite={overwrite})", overwrite);
    }

    // E: restore somewhere else
    [Test]
    public async Task E_Elsewhere()
    {
        await Setup();
        await Restore("E_Elsewhere", false, RESTOREFOLDER);
    }
}
