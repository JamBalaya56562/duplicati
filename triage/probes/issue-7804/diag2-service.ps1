<#
  Second diagnostic for duplicati/duplicati#7804: why the 2.4.1.0 service stops a few seconds after it starts.
  Run from an elevated PowerShell:   powershell -ExecutionPolicy Bypass -File .\diag2-service.ps1
  Afterwards remove everything with:  powershell -ExecutionPolicy Bypass -File .\cleanup-7804.ps1

  1. Installs 2.4.1.0 silently as a service (no TLS), as the documentation describes for unattended installs.
  2. Collects crash logs from the system temp folders.
  3. Starts the service with --debug-service and a verbose log file, and watches it for 30 seconds.
  4. Runs Duplicati.Server.exe once in this console for 20 seconds, as you, with its own data folder in
     .\consoledata and port 8299, to see whether it also fails outside the service.
  Your own %LOCALAPPDATA%\Duplicati is not used or touched. Output: .\diag2.txt and .\diag2-files\
#>
$ErrorActionPreference = 'Continue'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$newMsi  = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
$out     = Join-Path $here 'diag2.txt'
$files   = Join-Path $here 'diag2-files'
$logs    = Join-Path $here 'logs'
$install = 'C:\Program Files\Duplicati 2'
function W([string]$t) { $t | Tee-Object -FilePath $out -Append }
# Copies text files and leaves out lines that mention a password
function Save-Text([string]$path, [string]$name) {
    $dest = Join-Path $files $name
    Get-Content $path -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch 'password' } | Set-Content $dest
    W "  saved $path -> diag2-files\$name"
}
function Find-CrashLogs([datetime]$since) {
    foreach ($dir in 'C:\Windows\SystemTemp', 'C:\Windows\Temp', $env:TEMP) {
        Get-ChildItem $dir -Filter '*crashlog*.txt' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $since }
    }
}

$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this script from an elevated PowerShell.' }
$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
if (Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Duplicati' }) { throw 'Stopping, nothing was changed: Duplicati is installed. Run cleanup-7804.ps1 first.' }
if (Get-Service -Name Duplicati -ErrorAction SilentlyContinue) { throw 'Stopping, nothing was changed: the Duplicati service exists.' }
if (Test-Path 'HKLM:\SOFTWARE\DuplicatiTeam') { throw 'Stopping, nothing was changed: HKLM:\SOFTWARE\DuplicatiTeam exists. Run cleanup-7804.ps1 first.' }

if (Test-Path $out) { Remove-Item $out }
if (Test-Path $files) { Remove-Item $files -Recurse -Force }
New-Item -ItemType Directory -Force $files, $logs | Out-Null
$t0 = Get-Date
W "diag2 started $(Get-Date -Format s)"

W ''
W '--- 1. silent install of 2.4.1.0 as a service'
$i = Start-Process msiexec.exe -ArgumentList "/i `"$newMsi`" /qn ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature /l*v `"$logs\11-silent-install.log`"" -Wait -PassThru
W "msiexec exit code: $($i.ExitCode)"
Start-Sleep 20
$svc = Get-CimInstance Win32_Service -Filter "Name='Duplicati'"
W "service: state=$($svc.State) start=$($svc.StartMode) command=$($svc.PathName)"
W ("port 8200 listening: " + [bool](Get-NetTCPConnection -State Listen -LocalPort 8200 -ErrorAction SilentlyContinue))

W ''
W '--- 2. crash logs written since the install started'
$crash = @(Find-CrashLogs $t0)
if (-not $crash) { W 'none' }
foreach ($c in $crash) { W "$($c.FullName) $($c.LastWriteTime.ToString('HH:mm:ss')) $($c.Length) bytes"; Save-Text $c.FullName ('crash-' + $c.Name) }

W ''
W '--- 3. start the service with --debug-service and a verbose log file'
Stop-Service -Name Duplicati -Force -ErrorAction SilentlyContinue
$serverLog = Join-Path $files 'service-server.log'
$t1 = Get-Date
& sc.exe start Duplicati --debug-service "--log-file=$serverLog" --log-level=Verbose | ForEach-Object { W "  sc: $_" }
$last = ''
for ($s = 0; $s -lt 30; $s++) {
    $now = "status=$((Get-Service -Name Duplicati).Status) port8200=$([bool](Get-NetTCPConnection -State Listen -LocalPort 8200 -ErrorAction SilentlyContinue))"
    if ($now -ne $last) { W ("+{0,2}s  {1}" -f $s, $now); $last = $now }
    Start-Sleep 1
}
W 'Application event log since the start (all sources that mention Duplicati, plus .NET Runtime and Application Error):'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $t1.AddSeconds(-2) } -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -match 'Duplicati|\.NET Runtime|Application Error' -or $_.Message -match 'Duplicati' } | Sort-Object TimeCreated |
    ForEach-Object { W ("  {0} [{1} {2}] {3}" -f $_.TimeCreated.ToString('HH:mm:ss'), $_.ProviderName, $_.LevelDisplayName, (($_.Message -replace '\s+', ' ') -replace '(?i)password\S*', 'password<removed>')) }
if (Test-Path $serverLog) { W "service log file: $((Get-Item $serverLog).Length) bytes (diag2-files\service-server.log)" } else { W 'service log file: not written' }
foreach ($c in @(Find-CrashLogs $t1)) { W "crash log: $($c.FullName) $($c.LastWriteTime.ToString('HH:mm:ss'))"; Save-Text $c.FullName ('crash-svc-' + $c.Name) }
W 'Duplicati data folders and databases on this PC (service side):'
foreach ($dir in 'C:\ProgramData\Duplicati', 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati', 'C:\Windows\System32\config\systemprofile\AppData\Roaming\Duplicati', "$install\data") {
    if (Test-Path $dir) { Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { W ("  {0}  {1,10}  {2}" -f $_.LastWriteTime.ToString('HH:mm:ss'), $_.Length, $_.FullName) } } else { W "  $dir : not present" }
}

W ''
W '--- 4. Duplicati.Server.exe in this console for 20 seconds (own data folder, port 8299)'
$cdata = Join-Path $here 'consoledata'
New-Item -ItemType Directory -Force $cdata | Out-Null
$cout = Join-Path $files 'console-stdout.txt'; $cerr = Join-Path $files 'console-stderr.txt'
$proc = Start-Process (Join-Path $install 'Duplicati.Server.exe') -ArgumentList "--server-datafolder=`"$cdata`"", '--webservice-port=8299', '--webservice-interface=loopback', '--disable-db-encryption=true', "--log-file=`"$files\console-server.log`"", '--log-level=Verbose' -RedirectStandardOutput $cout -RedirectStandardError $cerr -PassThru -WindowStyle Hidden
$last = ''
for ($s = 0; $s -lt 20; $s++) {
    $now = "running=$(-not $proc.HasExited) port8299=$([bool](Get-NetTCPConnection -State Listen -LocalPort 8299 -ErrorAction SilentlyContinue))"
    if ($now -ne $last) { W ("+{0,2}s  {1}" -f $s, $now); $last = $now }
    Start-Sleep 1
}
if ($proc.HasExited) { W "console server exited with code $($proc.ExitCode)" } else { Stop-Process -Id $proc.Id -Force; W 'console server was still running after 20 seconds (stopped it)' }
foreach ($f in $cout, $cerr) { W "=== $([IO.Path]::GetFileName($f))"; Get-Content $f -Tail 40 -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch 'password' } | ForEach-Object { W "  $_" } }

W ''
W "diag2 done $(Get-Date -Format s). Duplicati is still installed; run cleanup-7804.ps1 next."
