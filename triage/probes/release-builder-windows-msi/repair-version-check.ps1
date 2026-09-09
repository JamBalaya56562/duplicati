# Run in an elevated (administrator) PowerShell.
# fix/msi-service-config-event, second try: in the earlier run (case D) a repair of the wixl MSI did not set
# DelayedAutostart again, because the repair skipped the service component: Duplicati.WindowsService.exe had
# no version in the File table, so the installed (versioned) file counted as newer.
# wixlevv-gui.msi is the same wixl MSI with DefaultVersion="$(var.ProductVersion)" on that file, and the
# product version equal to the file versions, as in a release build.
#   E: install with the service feature, set DelayedAutostart to 0, repair, check it is 1 again, uninstall.
# Everything is uninstalled at the end.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$msi = Join-Path $dir 'wixlevv-gui.msi'
$out = Join-Path $dir 'repair-version-check-result.txt'
$installDir = 'C:\Program Files\Duplicati 2'
$result = [System.Collections.Generic.List[string]]::new()
function Say($s) { $result.Add($s); $s }

Say "user: $env:USERDOMAIN\$env:USERNAME, elevated: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
if ((Get-Service Duplicati -ErrorAction SilentlyContinue) -or (Test-Path $installDir)) {
    Say 'STOP: Duplicati is installed on this machine; nothing was changed.'
    $result | Set-Content -Path $out -Encoding utf8
    return
}

function Msi($arguments, $log) {
    $p = Start-Process msiexec.exe -ArgumentList "$arguments /l*v `"$log`"" -Wait -PassThru
    Say "  msiexec $($arguments.Split(' ')[0]) exit code: $($p.ExitCode)"
    $errors = Select-String -Path $log -Pattern 'Return value 3|Error 1060|Error 1939|Error 1720|Error 1721|Error 1722' -Encoding unicode | Select-Object -First 5
    Say "  error lines in log: $(@($errors).Count)"
    $disallowed = @(Select-String -Path $log -Pattern 'Disallowing installation of component' -Encoding unicode).Count
    $svcAction = (Select-String -Path $log -Pattern 'Component: DuplicatiWindowsServiceComponent;.*' -Encoding unicode | Select-Object -First 1).Matches.Value
    Say "  disallowed components: $disallowed; $svcAction"
}

function ServiceState($label) {
    Say "[$label]"
    $svc = Get-Service Duplicati -ErrorAction SilentlyContinue
    Say "  service: $(if ($svc) { "$($svc.Status), StartType $($svc.StartType)" } else { '(none)' })"
    if ($svc) {
        $delayed = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati' -Name DelayedAutostart -ErrorAction SilentlyContinue).DelayedAutostart
        Say "  DelayedAutostart: $(if ($null -ne $delayed) { $delayed } else { '(none)' })"
    }
}

Say '=== E: wixl MSI with Event 5 and a versioned Duplicati.WindowsService.exe'
Msi "/i `"$msi`" /qn ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature" (Join-Path $dir 'check-e-install.log')
ServiceState 'E installed'
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati' -Name DelayedAutostart -Value 0 -ErrorAction SilentlyContinue
Say '  (DelayedAutostart set to 0 before the repair)'
Msi "/fvomus `"$msi`" /qn" (Join-Path $dir 'check-e-repair.log')
ServiceState 'E repaired'
Msi "/x `"$msi`" /qn" (Join-Path $dir 'check-e-uninstall.log')
ServiceState 'E uninstalled'
Say "  install folder left: $(Test-Path $installDir)"

$result | Set-Content -Path $out -Encoding utf8
"Written to $out"
