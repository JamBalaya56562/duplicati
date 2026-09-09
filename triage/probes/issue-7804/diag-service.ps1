<#
  Diagnostic for duplicati/duplicati#7804: why the Duplicati service stops a few seconds after it starts.
  Run from an elevated PowerShell WHILE repro-7804.ps1 waits at its last question (before step 5 uninstalls):
      powershell -ExecutionPolicy Bypass -File .\diag-service.ps1
  It only starts the Duplicati service that the test installed, and reads its logs. Output: .\diag.txt
#>
$ErrorActionPreference = 'Continue'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$out     = Join-Path $here 'diag.txt'
$install = 'C:\Program Files\Duplicati 2'
$svcData = 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati'
if (Test-Path $out) { Remove-Item $out }
function W([string]$t) { $t | Tee-Object -FilePath $out -Append }

$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this script from an elevated PowerShell.' }
if (-not (Get-Service -Name Duplicati -ErrorAction SilentlyContinue)) { throw 'The Duplicati service is not installed (did step 5 already run?).' }

W "diag started $(Get-Date -Format s)"
$svc = Get-CimInstance Win32_Service -Filter "Name='Duplicati'"
W "service: state=$($svc.State) start=$($svc.StartMode) account=$($svc.StartName)"
W "service command line: $($svc.PathName)"

W ''
W '--- start the service and watch it for 30 seconds'
$start = Get-Date
try { Start-Service -Name Duplicati -ErrorAction Stop; W 'Start-Service returned' } catch { W "Start-Service failed: $($_.Exception.Message)" }
$last = ''
for ($i = 0; $i -lt 30; $i++) {
    $s = (Get-Service -Name Duplicati).Status
    $listen = [bool](Get-NetTCPConnection -State Listen -LocalPort 8200 -ErrorAction SilentlyContinue)
    $now = "status=$s port8200=$listen"
    if ($now -ne $last) { W ("+{0,2}s  {1}" -f $i, $now); $last = $now }
    Start-Sleep 1
}
$pids = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Duplicati' } | ForEach-Object { "$($_.ProcessId) $($_.Name) $($_.CommandLine)" }
W ("Duplicati processes now: " + ($(if ($pids) { $pids -join ' | ' } else { 'none' })))

W ''
W '--- Application event log, source Duplicati, since the start'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $start.AddSeconds(-2) } -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -match 'Duplicati|\.NET Runtime|Application Error' } | Sort-Object TimeCreated |
    ForEach-Object { W ("{0} [{1} {2}] {3}" -f $_.TimeCreated.ToString('HH:mm:ss'), $_.ProviderName, $_.LevelDisplayName, ($_.Message -replace '\s+', ' ')) }

W ''
W "--- files in the service data folder ($svcData)"
if (Test-Path $svcData) {
    Get-ChildItem $svcData -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime |
        ForEach-Object { W ("{0}  {1,10}  {2}" -f $_.LastWriteTime.ToString('HH:mm:ss'), $_.Length, $_.FullName.Substring($svcData.Length)) }
    # Text logs written today; lines that mention a password are left out
    Get-ChildItem $svcData -Recurse -File -Include *.txt, *.log -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).Date } |
        ForEach-Object {
            W ''; W "=== last 60 lines of $($_.FullName.Substring($svcData.Length))"
            Get-Content $_.FullName -Tail 60 | Where-Object { $_ -notmatch 'password' } | ForEach-Object { W "  $_" }
        }
} else { W 'not present' }

W ''
W '--- install folder checks'
W ("System.IO.Compression.dll present: " + (Test-Path (Join-Path $install 'System.IO.Compression.dll')))
W ("files in install folder: " + (Get-ChildItem $install -File -ErrorAction SilentlyContinue).Count)
W ("Duplicati.WindowsService.exe version: " + (Get-Item (Join-Path $install 'Duplicati.WindowsService.exe')).VersionInfo.FileVersion)

W ''
W "diag done $(Get-Date -Format s). Send diag.txt."
