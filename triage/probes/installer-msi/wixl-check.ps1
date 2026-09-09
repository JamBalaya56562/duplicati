# Run in an elevated (administrator) PowerShell.
# The same checks as install-check.ps1 and upgrade-check.ps1, with the MSIs built by wixl,
# the tool the release uses. NOSCRIPT=true skips the certificate and service scripts.
#   W1: wixl branch, current user only (/qn) -> wixl branch 2.0.8.105 with the UI sequence (/qr)
#   W2: wixl master, default (/qn)            -> wixl branch 2.0.8.105 silent (/qn)
#   W3: wixl branch, default (/qn), then uninstalled
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$out = Join-Path $dir 'wixl-check-result.txt'
$branchCode = '{4242E4BB-41D1-42C6-96C7-3C5D0690D716}'
$v2Code = '{EE2DE5D8-0905-4861-A09D-15EF8A25CA19}'
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

$result = @()
$result += State 'before'

$result += '=== W1'
$result += Msi "/i `"$(Join-Path $dir 'wixl-branch.msi')`" /qn NOSCRIPT=true STARTUP_FOR_CURRENT_USER=1" 'W1-v1'
$result += State 'W1 after wixl branch, STARTUP_FOR_CURRENT_USER=1'
$result += Msi "/i `"$(Join-Path $dir 'wixl-branch-v2.msi')`" /qr NOSCRIPT=true" 'W1-v2'
$result += State 'W1 after upgrade to wixl v2 (/qr)'
$result += Msi "/x $v2Code /qn NOSCRIPT=true" 'W1-uninstall'
$result += State 'W1 after uninstall'

$result += '=== W2'
$result += Msi "/i `"$(Join-Path $dir 'wixl-master.msi')`" /qn NOSCRIPT=true" 'W2-v1'
$result += State 'W2 after wixl master, default'
$result += Msi "/i `"$(Join-Path $dir 'wixl-branch-v2.msi')`" /qn NOSCRIPT=true" 'W2-v2'
$result += State 'W2 after upgrade to wixl v2 (/qn)'
$result += Msi "/x $v2Code /qn NOSCRIPT=true" 'W2-uninstall'
$result += State 'W2 after uninstall'

$result += '=== W3'
$result += Msi "/i `"$(Join-Path $dir 'wixl-branch.msi')`" /qn NOSCRIPT=true" 'W3-install'
$result += State 'W3 after wixl branch, default'
$result += Msi "/x $branchCode /qn NOSCRIPT=true" 'W3-uninstall'
$result += State 'W3 after uninstall'

$result += "Program Files\Duplicati 2 left: $(Test-Path 'C:\Program Files\Duplicati 2')"
$result | Set-Content -Path $out -Encoding utf8
$result
