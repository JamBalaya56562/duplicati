# Runs a command line in a new cmd.exe console window, then reads what that console shows.
# Usage: pwsh -File capture-console.ps1 -CmdLine '<cmd.exe command line>' [-WaitSeconds 8]
param([Parameter(Mandatory)] [string] $CmdLine, [int] $WaitSeconds = 8)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ConsoleReader {
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool FreeConsole();
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool AttachConsole(int pid);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] struct COORD { public short X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct SMALL_RECT { public short L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] struct CSBI { public COORD Size; public COORD Cursor; public short Attr; public SMALL_RECT Window; public COORD Max; }
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetConsoleScreenBufferInfo(IntPtr h, out CSBI info);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool ReadConsoleOutputCharacter(IntPtr h, StringBuilder buf, uint len, COORD at, out uint read);

    public static string Read(int pid) {
        FreeConsole();
        if (!AttachConsole(pid)) return "AttachConsole failed: " + Marshal.GetLastWin32Error();
        try {
            var h = CreateFile("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
            if (!GetConsoleScreenBufferInfo(h, out var info)) return "GetConsoleScreenBufferInfo failed: " + Marshal.GetLastWin32Error();
            var sb = new StringBuilder();
            for (short y = 0; y <= info.Cursor.Y; y++) {
                var line = new StringBuilder(info.Size.X);
                ReadConsoleOutputCharacter(h, line, (uint)info.Size.X, new COORD { X = 0, Y = y }, out var n);
                sb.AppendLine(line.ToString(0, (int)n).TrimEnd());
            }
            CloseHandle(h);
            return sb.ToString();
        } finally { FreeConsole(); }
    }
}
'@

$p = Start-Process -FilePath cmd.exe -ArgumentList '/k', $CmdLine -PassThru -WindowStyle Minimized
Start-Sleep -Seconds $WaitSeconds
$text = [ConsoleReader]::Read($p.Id)
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
$text
