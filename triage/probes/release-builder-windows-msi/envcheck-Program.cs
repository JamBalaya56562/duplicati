// Calls ReleaseBuilder's EnvHelper.FindCommand the way Configuration.Commands.Create does,
// with the override environment variable set to different values.
using ReleaseBuilder;

var node = args[0];   // folder with npm (sh script), npm.cmd and npm.ps1, no npm.exe
var wix = args[1];    // a wix.exe
var txt = args[2];    // an existing file that is not executable
var cases = new (string Name, string? Value)[] {
    ("NPM = npm.cmd", Path.Combine(node, "npm.cmd")),
    ("NPM = npm (no extension; an sh script of that name exists)", Path.Combine(node, "npm")),
    ("NPM = wix.exe (an .exe)", wix),
    ("NPM = missing folder\npm.cmd", @"C:\no-such-folder\npm.cmd"),
    ("NPM = an existing .txt file", txt),
};
DebugInfo.Print(Path.Combine(node, "npm.cmd"));
foreach (var (name, value) in cases)
{
    Environment.SetEnvironmentVariable("NPM", value);
    try { Console.WriteLine($"{name} -> {EnvHelper.FindCommand("npm", "NPM")}"); }
    catch (Exception ex) { Console.WriteLine($"{name} -> exception: {ex.Message}"); }
}
