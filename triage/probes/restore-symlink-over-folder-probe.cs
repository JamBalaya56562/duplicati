using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using Duplicati.Library.Utility;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe: a path that was a symbolic link at backup time holds real data at restore time.
// Does a restore to the original location delete that data?
public class Item7rProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBE7R " + msg);

    private bool UseJunction;

    [TearDown]
    public void RemoveJunction()
    {
        // The recursive delete of the test folders cannot remove a junction
        if (UseJunction && Directory.Exists(Link) && new DirectoryInfo(Link).LinkTarget != null)
            new DirectoryInfo(Link).Delete();
        UseJunction = false;
    }

    private string Outside => this.DATAFOLDER.TrimEnd(Path.DirectorySeparatorChar) + "-outside";
    private string Link => Path.Combine(this.DATAFOLDER, "link");
    private string FileLink => Path.Combine(this.DATAFOLDER, "flink.txt");

    private static string Describe(string root)
    {
        if (!Directory.Exists(root)) return "(none)";
        var items = new List<string>();
        var q = new Stack<string>();
        q.Push(root);
        var trim = root.TrimEnd(Path.DirectorySeparatorChar).Length;
        while (q.Count > 0)
        {
            var d = q.Pop();
            foreach (var e in new DirectoryInfo(d).EnumerateFileSystemInfos())
            {
                var rel = e.FullName.Substring(trim);
                if (e.LinkTarget != null)
                    items.Add($"{rel} -> {Path.GetFileName(e.LinkTarget)}");
                else if (e is DirectoryInfo)
                {
                    items.Add(rel + Path.DirectorySeparatorChar);
                    q.Push(e.FullName);
                }
                else
                    items.Add($"{rel} [{File.ReadAllText(e.FullName)}]");
            }
        }
        items.Sort(StringComparer.Ordinal);
        return string.Join(", ", items);
    }

    private static string Msgs(IBasicResults r)
        => $"errors={r.Errors.Count()} warnings={r.Warnings.Count()} {string.Join(" | ", r.Errors.Concat(r.Warnings)).Replace("\n", " ")}";

    private void Setup()
    {
        File.WriteAllText(Path.Combine(this.DATAFOLDER, "kept.txt"), "kept");
        if (Directory.Exists(Outside)) Directory.Delete(Outside, true);
        Directory.CreateDirectory(Outside);
        File.WriteAllText(Path.Combine(Outside, "target.txt"), "target-content");
        File.WriteAllText(Path.Combine(Outside, "file-target.txt"), "file-target-content");
        try
        {
            if (UseJunction)
            {
                var p = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("cmd.exe", $"/c mklink /J \"{Link}\" \"{Outside}\"") { UseShellExecute = false, RedirectStandardOutput = true });
                p!.WaitForExit();
                W($"junction: {new DirectoryInfo(Link).LinkTarget}");
            }
            else
                Directory.CreateSymbolicLink(Link, Outside);
            File.CreateSymbolicLink(FileLink, Path.Combine(Outside, "file-target.txt"));
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException)
        {
            Assert.Ignore("no symlinks: " + ex.Message);
        }
    }

    // change: "none" (links intact), "folder" (dir link replaced by a real folder with data),
    // "file" (file link replaced by a real file). overwrite: the --overwrite option.
    // filter: restore only this path below the data folder, or everything.
    private async Task Run(string name, string change, bool overwrite, string filter = null)
    {
        Setup();
        var options = new Dictionary<string, string>(this.TestOptions);
        using (var c = new Controller("file://" + this.TARGETFOLDER, options, null))
            W($"{name} backup: {Msgs(await c.BackupAsync([this.DATAFOLDER]))}");
        using (var c = new Controller("file://" + this.TARGETFOLDER, options, null))
        {
            var r = await c.ListAsync("*");
            W($"{name} list: {string.Join(", ", r.Files.Select(x => x.Path.Substring(this.DATAFOLDER.TrimEnd(Path.DirectorySeparatorChar).Length)))}");
        }

        File.WriteAllText(Path.Combine(this.DATAFOLDER, "kept.txt"), "kept-changed");
        if (change == "folder")
        {
            new DirectoryInfo(Link).Delete();
            Directory.CreateDirectory(Path.Combine(Link, "sub"));
            File.WriteAllText(Path.Combine(Link, "mine.txt"), "user-data");
            File.WriteAllText(Path.Combine(Link, "sub", "mine2.txt"), "user-data-2");
        }
        else if (change == "file")
        {
            File.Delete(FileLink);
            File.WriteAllText(FileLink, "user-file-data");
        }
        W($"{name} data before restore: {Describe(this.DATAFOLDER)}");
        W($"{name} outside before restore: {Describe(Outside)}");

        var ropts = new Dictionary<string, string>(options) { ["overwrite"] = overwrite ? "true" : "false" };
        using (var c = new Controller("file://" + this.TARGETFOLDER, ropts, null))
        {
            var paths = filter == null ? null : new[] { Path.Combine(this.DATAFOLDER, filter) };
            try { W($"{name} restore: {Msgs(await c.RestoreAsync(paths))}"); }
            catch (Exception ex) { W($"{name} restore: EXCEPTION {ex.GetType().Name}: {ex.Message}"); }
        }
        W($"{name} data after restore: {Describe(this.DATAFOLDER)}");
        W($"{name} outside after restore: {Describe(Outside)}");
    }

    [Test] public Task A_Folder_Overwrite() => Run("A_Folder_Overwrite", "folder", true);
    [Test] public Task B_Folder_NoOverwrite() => Run("B_Folder_NoOverwrite", "folder", false);
    [Test] public Task C_Folder_Overwrite_OnlyLink() => Run("C_Folder_Overwrite_OnlyLink", "folder", true, "link" + Path.DirectorySeparatorChar);
    [Test] public Task D_Intact_Overwrite() => Run("D_Intact_Overwrite", "none", true);
    [Test] public Task E_File_Overwrite() => Run("E_File_Overwrite", "file", true);
    [Test] public Task F_File_NoOverwrite() => Run("F_File_NoOverwrite", "file", false);

    // Windows junction instead of a symbolic link for the folder
    [Test] public Task G_Junction_Folder_Overwrite() { if (!OperatingSystem.IsWindows()) Assert.Ignore("junctions are Windows only"); UseJunction = true; return Run("G_Junction_Folder_Overwrite", "folder", true); }
    [Test] public Task H_Junction_Folder_NoOverwrite() { if (!OperatingSystem.IsWindows()) Assert.Ignore("junctions are Windows only"); UseJunction = true; return Run("H_Junction_Folder_NoOverwrite", "folder", false); }
    [Test] public Task I_Junction_Intact_Overwrite() { if (!OperatingSystem.IsWindows()) Assert.Ignore("junctions are Windows only"); UseJunction = true; return Run("I_Junction_Intact_Overwrite", "none", true); }
}
