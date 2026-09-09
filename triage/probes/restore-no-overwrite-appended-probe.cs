using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe: does a restore to the original location with --overwrite=false change a file that
// was appended to after the backup?
public class Item7kProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBE7K " + msg);

    private string Target => Path.Combine(this.DATAFOLDER, "file.bin");

    private static string Msgs(IBasicResults r)
        => $"errors={r.Errors.Count()} warnings={r.Warnings.Count()} {string.Join(" | ", r.Errors.Concat(r.Warnings)).Replace("\n", " ")}";

    private string Describe()
        => string.Join(", ", Directory.EnumerateFiles(this.DATAFOLDER)
            .OrderBy(x => x, StringComparer.Ordinal)
            .Select(x => $"{Path.GetFileName(x)} ({new FileInfo(x).Length} bytes, sha={Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(File.ReadAllBytes(x)))[..8]})"));

    // original: the bytes at backup time. changed: the bytes at restore time.
    private async Task Run(string name, byte[] original, byte[] changed, bool overwrite, bool legacy)
    {
        File.WriteAllBytes(Target, original);
        var options = new Dictionary<string, string>(this.TestOptions);
        using (var c = new Controller("file://" + this.TARGETFOLDER, options, null))
            W($"{name} backup: {Msgs(await c.BackupAsync([this.DATAFOLDER]))}");

        File.WriteAllBytes(Target, changed);
        W($"{name} before restore: {Describe()}  [original {original.Length} bytes, sha={Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(original))[..8]}; changed {changed.Length} bytes, sha={Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(changed))[..8]}]");

        var ropts = new Dictionary<string, string>(options)
        {
            ["overwrite"] = overwrite ? "true" : "false",
            ["restore-legacy"] = legacy ? "true" : "false"
        };
        using (var c = new Controller("file://" + this.TARGETFOLDER, ropts, null))
            W($"{name} restore: {Msgs(await c.RestoreAsync(null))}");
        W($"{name} after restore: {Describe()}");
        var now = File.ReadAllBytes(Target);
        W($"{name} RESULT: file.bin is {(now.SequenceEqual(changed) ? "UNCHANGED (as it was before restore)" : now.SequenceEqual(original) ? "THE BACKED-UP VERSION" : "SOMETHING ELSE")}");
    }

    private static byte[] Bytes(int length, int seed)
    {
        var b = new byte[length];
        new Random(seed).NextBytes(b);
        return b;
    }

    private static byte[] Concat(byte[] a, byte[] b) => [.. a, .. b];

    // Small file, one block: "kept" -> "kept-changed"
    [Test] public Task A_Appended_Small_NoOverwrite() => Run("A_Appended_Small_NoOverwrite", "kept"u8.ToArray(), "kept-changed"u8.ToArray(), false, false);
    // Control: different content, not a prefix
    [Test] public Task B_Different_Small_NoOverwrite() => Run("B_Different_Small_NoOverwrite", "kept"u8.ToArray(), "KEPT-changed"u8.ToArray(), false, false);
    // 25 KB (blocksize is 10 KB in the tests, so 3 blocks with a partial last one), 5 KB appended
    [Test] public Task C_Appended_MultiBlock_NoOverwrite() => Run("C_Appended_MultiBlock_NoOverwrite", Bytes(25 * 1024, 1), Concat(Bytes(25 * 1024, 1), Bytes(5 * 1024, 2)), false, false);
    // Control: overwrite=true, where going back to the backed-up version is asked for
    [Test] public Task D_Appended_MultiBlock_Overwrite() => Run("D_Appended_MultiBlock_Overwrite", Bytes(25 * 1024, 1), Concat(Bytes(25 * 1024, 1), Bytes(5 * 1024, 2)), true, false);
    // Legacy restore
    [Test] public Task E_Appended_Small_NoOverwrite_Legacy() => Run("E_Appended_Small_NoOverwrite_Legacy", "kept"u8.ToArray(), "kept-changed"u8.ToArray(), false, true);
    [Test] public Task F_Appended_MultiBlock_NoOverwrite_Legacy() => Run("F_Appended_MultiBlock_NoOverwrite_Legacy", Bytes(25 * 1024, 1), Concat(Bytes(25 * 1024, 1), Bytes(5 * 1024, 2)), false, true);
    [Test] public Task G_Different_Small_NoOverwrite_Legacy() => Run("G_Different_Small_NoOverwrite_Legacy", "kept"u8.ToArray(), "KEPT-changed"u8.ToArray(), false, true);
    // Changed in the middle, same length: should be kept aside
    [Test] public Task H_ChangedMiddle_MultiBlock_NoOverwrite() => Run("H_ChangedMiddle_MultiBlock_NoOverwrite", Bytes(25 * 1024, 1), Concat(Concat(Bytes(10 * 1024, 1), Bytes(10 * 1024, 3)), Bytes(25 * 1024, 1)[(20 * 1024)..]), false, false);
}
