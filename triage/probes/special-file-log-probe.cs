#nullable enable

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): which special files does the backup exclude on Linux, and what
// does it log for each?
[NonParallelizable]
public class SpecialFileLogProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBESPECIAL " + msg);

    [Test]
    public async Task SpecialFiles()
    {
        if (!OperatingSystem.IsLinux())
            Assert.Ignore("Linux only");

        File.WriteAllText(Path.Combine(DATAFOLDER, "regular.txt"), "a");
        Process.Start("mkfifo", Path.Combine(DATAFOLDER, "a-fifo"))!.WaitForExit();
        Process.Start("python3", $"-c \"import socket; socket.socket(socket.AF_UNIX).bind('{Path.Combine(DATAFOLDER, "a-socket")}')\"")!.WaitForExit();
        foreach (var f in Directory.GetFileSystemEntries(DATAFOLDER))
            W($"source entry {Path.GetFileName(f)}");

        var options = new Dictionary<string, string>(TestOptions)
        {
            ["log-file"] = Path.Combine(BASEFOLDER, "special.log"),
            ["log-file-log-level"] = "verbose",
        };

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            var r = await c.BackupAsync(new[] { DATAFOLDER, "/dev/null" });
            W($"result {r.ParsedResult}, examined {r.ExaminedFiles}, added {r.AddedFiles}");
        }

        foreach (var line in File.ReadAllLines(Path.Combine(BASEFOLDER, "special.log")))
            if (line.Contains("Excluding") || line.Contains("a-fifo") || line.Contains("a-socket") || line.Contains("/dev/null"))
                W("log: " + (line.Length > 230 ? line.Substring(0, 230) : line));
    }
}
