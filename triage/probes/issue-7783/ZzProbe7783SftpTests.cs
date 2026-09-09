using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Temporary probe for #7783 against a real SFTP server, not to be committed.
[TestFixture]
public class ZzProbe7783SftpTests : BasicSetupHelper
{
    [Test]
    [TestCase("UseRemoteState")]
    [TestCase("UseLocalState")]
    public async Task Probe(string stateMode)
    {
        var url = Environment.GetEnvironmentVariable("DUPLICATI_7783_SFTP_URL");
        if (string.IsNullOrEmpty(url))
            Assert.Ignore("no url");

        var target = Path.Combine(BASEFOLDER, "sftp-target-" + stateMode);
        if (Directory.Exists(target)) Directory.Delete(target, true);
        Directory.CreateDirectory(target);
        var source = "@" + Path.Combine(Path.GetPathRoot(target)!, "duplicati-virtual-7783", "nas") + "|" + url;
        var local = Path.Combine(BASEFOLDER, "sftp-local");
        if (Directory.Exists(local)) Directory.Delete(local, true);
        Directory.CreateDirectory(local);
        File.WriteAllText(Path.Combine(local, "l.txt"), "local");

        foreach (var (label, sources) in new[] { ("single", new[] { source }), ("with-local", new[] { source, local }) })
        {
            var t = Path.Combine(target, label);
            Directory.CreateDirectory(t);
            for (var run = 1; run <= 2; run++)
            {
                var opts = new Dictionary<string, string> { ["no-encryption"] = "true", ["snapshot-policy"] = "off", ["sync-remote-state"] = stateMode, ["ssh-accept-any-fingerprints"] = "true", ["dbpath"] = Path.Combine(BASEFOLDER, $"sftp-{stateMode}-{label}.sqlite") };
                using var c = new Controller("file://" + t.Replace('\\', '/'), opts, null);
                try
                {
                    var res = await c.SyncAsync(sources, null);
                    TestContext.Progress.WriteLine($"PROBE7783 {stateMode} {label} run{run}: uploaded={res.FilesUploaded} deleted={res.FilesDeleted} folders={res.FoldersCreated} warnings={res.Warnings.Count()} [{string.Join(" | ", res.Warnings).Replace("fixture-7783-only", "<PW>")}] errors=[{string.Join(" | ", res.Errors)}]");
                }
                catch (Exception ex) { TestContext.Progress.WriteLine($"PROBE7783 {stateMode} {label} run{run}: THROWS {ex.GetType().Name}: {ex.Message}"); }
            }
            foreach (var f in Directory.GetFiles(t, "*", SearchOption.AllDirectories).Where(x => !x.EndsWith(".sqlite")).OrderBy(x => x))
                TestContext.Progress.WriteLine($"PROBE7783 {stateMode} {label}:   {Path.GetRelativePath(t, f)} = \"{File.ReadAllText(f).TrimEnd()}\"");
        }
    }
}
