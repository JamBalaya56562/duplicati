# Run in an elevated (administrator) PowerShell.
# Installs the test MSI built from feat/installer-startup-current-user twice, silently, and checks
# where the startup entry goes; uninstalls after each run. NOSCRIPT=true skips the script actions
# (certificates, service), which the startup choice does not depend on.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$msi = Join-Path $dir 'branch.msi'
$out = Join-Path $dir 'install-check-result.txt'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$markerKey = 'HKCU:\Software\DuplicatiTeam\Duplicati\UserStartupShortcut'
$commonLnk = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup\Duplicati.lnk'
$userLnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Duplicati.lnk'

function State($label) {
    $run = (Get-ItemProperty $runKey -Name Duplicati -ErrorAction SilentlyContinue).Duplicati
    $marker = (Get-ItemProperty $markerKey -Name Enabled -ErrorAction SilentlyContinue).Enabled
    "[$label]"
    "  HKCU Run Duplicati      : $(if ($run) { $run } else { '(none)' })"
    "  HKCU marker Enabled     : $(if ($marker) { $marker } else { '(none)' })"
    "  all-users Startup .lnk  : $(Test-Path $commonLnk)"
    "  current-user Startup .lnk: $(Test-Path $userLnk)"
}

function Msi($arguments, $log) {
    $p = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    "  msiexec exit code: $($p.ExitCode) (log: $log)"
}

$result = @()
$result += "user: $env:USERDOMAIN\$env:USERNAME, elevated: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
$result += State 'before'

# A: only for the current user
$log = Join-Path $dir 'install-a.log'
$result += Msi "/i `"$msi`" /qn NOSCRIPT=true STARTUP_FOR_CURRENT_USER=1 /l*v `"$log`"" $log
$result += State 'A installed, STARTUP_FOR_CURRENT_USER=1'
$log = Join-Path $dir 'uninstall-a.log'
$result += Msi "/x `"$msi`" /qn NOSCRIPT=true /l*v `"$log`"" $log
$result += State 'A uninstalled'

# B: the default, every user
$log = Join-Path $dir 'install-b.log'
$result += Msi "/i `"$msi`" /qn NOSCRIPT=true /l*v `"$log`"" $log
$result += State 'B installed, default'
$log = Join-Path $dir 'uninstall-b.log'
$result += Msi "/x `"$msi`" /qn NOSCRIPT=true /l*v `"$log`"" $log
$result += State 'B uninstalled'

$result += "Program Files\Duplicati 2 left: $(Test-Path 'C:\Program Files\Duplicati 2')"
$result | Set-Content -Path $out -Encoding utf8
$result
