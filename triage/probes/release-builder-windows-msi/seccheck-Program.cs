// Calls MsiSecureProperties the way BuildMsiPackage does: with the fragments of the resource folder.
using ReleaseBuilder;

var resources = args[0];   // ReleaseBuilder/Resources/Windows
foreach (var (sub, files) in new[] {
    ("TrayIcon", new[] { "InstallOptionsDlg.wxs", "ExitDialog.wxs", "Shortcuts.wxs", "Duplicati.wxs" }),
    ("Agent", new[] { "InstallOptionsDlg.wxs", "ExitDialog.wxs", "Shortcuts.wxs", "Duplicati.wxs" }) })
{
    var fragments = files.Select(x => Path.Combine(resources, sub, x)).Where(File.Exists);
    File.WriteAllLines(Path.Combine(AppContext.BaseDirectory, $"queries-{sub}.txt"), MsiSecureProperties.GetQueries(MsiSecureProperties.Get(fragments)));
    Console.WriteLine($"{sub}: {string.Join(";", MsiSecureProperties.Get(fragments))}");
}
