param([Parameter(Mandatory)] [string] $Revision, [Parameter(Mandatory)] [string] $OutName)
# Writes ReleaseBuilder/Resources/Windows of a revision, byte for byte, to wixl-<OutName>
$ErrorActionPreference = 'Stop'
$scratch = Split-Path -Parent $PSCommandPath
$repo = 'C:\Users\Jam\Documents\duplicati'
$jj = (Get-ChildItem "$env:USERPROFILE\AppData\Local\mise\installs\jj\*\jj.exe" | Select-Object -Last 1).FullName
$work = Join-Path $scratch "wixl-$OutName"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
$sub = 'ReleaseBuilder/Resources/Windows'
foreach ($f in (& $jj file list -r $Revision "$sub/TrayIcon" "$sub/WixUIExtension")) {
    $dest = Join-Path $work ($f.Substring($sub.Length + 1) -replace '/', '\')
    New-Item -ItemType Directory -Force (Split-Path -Parent $dest) | Out-Null
    $p = Start-Process -FilePath $jj -ArgumentList @('file', 'show', '-r', $Revision, $f) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $dest -WorkingDirectory $repo
    if ($p.ExitCode -ne 0) { throw "jj file show failed for $f" }
}
"Exported $Revision to $work"
