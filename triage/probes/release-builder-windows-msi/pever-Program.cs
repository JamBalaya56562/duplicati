using System.Diagnostics;
// args[0] = folder, args[1] = output list. On Windows also compares with FileVersionInfo (the Windows API).
var files = Directory.GetFiles(args[0], "*", SearchOption.AllDirectories).OrderBy(x => x, StringComparer.Ordinal).ToArray();
var lines = new List<string>();
int same = 0, diff = 0, both0 = 0;
foreach (var f in files)
{
    var mine = ReleaseBuilder.PeFileVersion.TryRead(f);
    lines.Add($"{Path.GetRelativePath(args[0], f).Replace(Path.DirectorySeparatorChar, '/')}\t{mine}");
    if (!OperatingSystem.IsWindows()) continue;
    var v = FileVersionInfo.GetVersionInfo(f);
    Version? win = (v.FileMajorPart | v.FileMinorPart | v.FileBuildPart | v.FilePrivatePart) == 0 ? null : new Version(v.FileMajorPart, v.FileMinorPart, v.FileBuildPart, v.FilePrivatePart);
    if (win == null && mine == null) both0++;
    else if (Equals(win, mine)) same++;
    else { diff++; if (diff <= 10) Console.WriteLine($"DIFF {f}: windows={win} mine={mine}"); }
}
File.WriteAllLines(args[1], lines);
Console.WriteLine($"files={files.Length} same={same} neither={both0} diff={diff} withVersion={lines.Count(l => !l.EndsWith('\t'))}");
