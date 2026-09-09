# Run in an elevated (administrator) PowerShell.
# Installs a 2.0.8.104 test MSI, upgrades it with the 2.0.8.105 test MSI, records where the
# startup entry is, and uninstalls. NOSCRIPT=true skips the certificate and service scripts.
#   U1: branch, current user only -> v2 with the UI sequence (/qr), no property passed
#   U2: branch, current user only -> v2 silent (/qn), no property passed
#   U3: master (before the change), default -> v2 silent
#   U4: branch, default -> v2 with the UI sequence (/qr)
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$out = Join-Path $dir 'upgrade-check-result.txt'
$v2Code = '{ADE6A7FB-0B3F-45CA-BDFF-42054BE66EA1}'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$markerKey = 'HKCU:\Software\DuplicatiTeam\Duplicati\UserStartupShortcut'
$commonLnk = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup\Duplicati.lnk'

function State($label) {
    $run = (Get-ItemProperty $runKey -Name Duplicati -ErrorAction SilentlyContinue).Duplicati
    $marker = (Get-ItemProperty $markerKey -Name Enabled -ErrorAction SilentlyContinue).Enabled
    "[$label]"
    "  HKCU Run Duplicati     : $(if ($run) { $run } else { '(none)' })"
    "  HKCU marker Enabled    : $(if ($marker) { $marker } else { '(none)' })"
    "  all-users Startup .lnk : $(Test-Path $commonLnk)"
}

function Msi($arguments, $name) {
    $log = Join-Path $dir "$name.log"
    $p = Start-Process msiexec.exe -ArgumentList "$arguments /l*v `"$log`"" -Wait -PassThru
    "  msiexec $name exit code: $($p.ExitCode)"
}

function Case($name, $v1, $v1Args, $v2Ui) {
    "=== $name"
    Msi "/i `"$(Join-Path $dir $v1)`" /qn NOSCRIPT=true $v1Args" "$name-v1"
    State "$name after $v1 $v1Args"
    Msi "/i `"$(Join-Path $dir 'branch-v2.msi')`" $v2Ui NOSCRIPT=true" "$name-v2"
    State "$name after upgrade to v2 ($v2Ui)"
    Msi "/x $v2Code /qn NOSCRIPT=true" "$name-uninstall"
    State "$name after uninstall"
}

$result = @()
$result += State 'before'
$result += Case 'U1' 'branch.msi' 'STARTUP_FOR_CURRENT_USER=1' '/qr'
$result += Case 'U2' 'branch.msi' 'STARTUP_FOR_CURRENT_USER=1' '/qn'
$result += Case 'U3' 'master.msi' '' '/qn'
$result += Case 'U4' 'branch.msi' '' '/qr'
$result += "Program Files\Duplicati 2 left: $(Test-Path 'C:\Program Files\Duplicati 2')"
$result | Set-Content -Path $out -Encoding utf8
$result
