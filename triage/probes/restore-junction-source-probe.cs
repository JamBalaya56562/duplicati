using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): the backup source is itself a junction. What does a restore do?
public class RootJunctionProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBERJ " + msg);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WIN32_FIND_DATA
    {
        public uint dwFileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME a, b, c;
        public uint h, l, dwReserved0, r1;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string n;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)] public string an;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr FindFirstFileW(string lpFileName, out WIN32_FIND_DATA d);
    [DllImport("kernel32.dll")]
    private static extern bool FindClose(IntPtr h);

    private static string Kind(string path)
    {
        var h = FindFirstFileW(path.TrimEnd('\\'), out var d);
        if (h == new IntPtr(-1)) return "(none)";
        FindClose(h);
        if ((d.dwFileAttributes & (uint)FileAttributes.ReparsePoint) == 0) return "real folder";
        return d.dwReserved0 == 0xA0000003 ? "JUNCTION" : d.dwReserved0 == 0xA000000C ? "SYMLINK" : $"tag 0x{d.dwReserved0:X8}";
    }

    private string Outside => this.DATAFOLDER.TrimEnd('\\') + "-outside";
    private string Link => Path.Combine(this.DATAFOLDER, "junction");

    private static string Msgs(IBasicResults r)
        => $"errors={r.Errors.Count()} warnings={r.Warnings.Count()} {string.Join(" | ", r.Errors.Concat(r.Warnings)).Replace("\n", " ")}";

    private string Describe(string root)
    {
        var kind = Kind(root);
        if (kind == "(none)") return kind;
        string[] items;
        try { items = Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories).Select(x => x.Substring(root.Length) + $" [{File.ReadAllText(x)}]").OrderBy(x => x).ToArray(); }
        catch (Exception ex) { items = [ex.GetType().Name]; }
        return $"[{kind}] " + string.Join(", ", items);
    }

    [TearDown]
    public void Remove()
    {
        if (new DirectoryInfo(Link).LinkTarget != null)
            new DirectoryInfo(Link).Delete();
    }

    private async Task Setup()
    {
        if (!OperatingSystem.IsWindows()) Assert.Ignore();
        if (Directory.Exists(Outside)) Directory.Delete(Outside, true);
        Directory.CreateDirectory(Path.Combine(Outside, "sub"));
        File.WriteAllText(Path.Combine(Outside, "a.txt"), "a");
        File.WriteAllText(Path.Combine(Outside, "sub", "b.txt"), "b");
        using (var p = Process.Start(new ProcessStartInfo("cmd.exe", $"/c mklink /J \"{Link}\" \"{Outside}\"") { UseShellExecute = false, RedirectStandardOutput = true })!)
            p.WaitForExit();
        W($"setup: {Kind(Link)}");
        using var c = new Controller("file://" + this.TARGETFOLDER, new Dictionary<string, string>(this.TestOptions), null);
        W($"backup: {Msgs(await c.BackupAsync([Link + "\\"]))}");
    }

    private async Task Restore(string name, string restorePath = null)
    {
        W($"{name} before: link={Describe(Link)} ; outside={Describe(Outside)}");
        var options = new Dictionary<string, string>(this.TestOptions) { ["overwrite"] = "true" };
        if (restorePath != null) options["restore-path"] = restorePath;
        using (var c = new Controller("file://" + this.TARGETFOLDER, options, null))
            W($"{name} restore: {Msgs(await c.RestoreAsync(null))}");
        W($"{name} after: link={Describe(Link)} ; outside={Describe(Outside)}" + (restorePath != null ? $" ; restored={Describe(restorePath)}" : ""));
    }

    [Test] public async Task A_Intact() { await Setup(); File.WriteAllText(Path.Combine(Outside, "a.txt"), "changed"); await Restore("A_Intact"); }
    [Test] public async Task A2_ReplacedBySymlink() { await Setup(); new DirectoryInfo(Link).Delete(); Directory.CreateSymbolicLink(Link, Outside); await Restore("A2_ReplacedBySymlink"); }
    [Test] public async Task B_LinkGone() { await Setup(); new DirectoryInfo(Link).Delete(); await Restore("B_LinkGone"); }
    [Test] public async Task C_BothGone() { await Setup(); new DirectoryInfo(Link).Delete(); Directory.Delete(Outside, true); await Restore("C_BothGone"); }
    [Test] public async Task E_Elsewhere() { await Setup(); await Restore("E_Elsewhere", RESTOREFOLDER); }
}
