# Run in an elevated (administrator) PowerShell.
# Installs the TrayIcon MSI that ReleaseBuilder built with WiX on Windows (fix/release-builder-windows-msi)
# and checks what the WiX-only elements do. Every run is uninstalled again at the end.
#   A: silent install with INSTALL_PRELOAD=true and NOSCRIPT=true
#      -> preload.json copied from the MSI folder, the install folder ACL, removal on uninstall
#   B: silent install with the service feature (the script custom actions run, 32-bit)
#      -> service registered as delayed auto start, no script errors, uninstall without error 1060
#   C: the same as B with the wixl MSI built from the same files, for comparison
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$wixMsi = Join-Path $dir 'build\packages\duplicati-2.0.0.99_debug_2026-11-09-win-x64-gui.msi'
$wixlMsi = Join-Path $dir 'wixl-gui.msi'
$out = Join-Path $dir 'wix-install-check-result.txt'
$installDir = 'C:\Program Files\Duplicati 2'
$result = [System.Collections.Generic.List[string]]::new()
function Say($s) { $result.Add($s); $s }

$installer = New-Object -ComObject WindowsInstaller.Installer
function Related($code) { @($installer.GetType().InvokeMember('RelatedProducts', 'GetProperty', $null, $installer, @($code))).Count }

Say "user: $env:USERDOMAIN\$env:USERNAME, elevated: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
$trayRelated = Related '{1C94BC5A-2BF2-4273-9D8F-2CB30E780D16}'
$agentRelated = Related '{BC5A1C94-2BF2-4273-9D8F-780D162CB30E}'
Say "installed Duplicati products: TrayIcon $trayRelated, Agent $agentRelated; service 'Duplicati' exists: $([bool](Get-Service Duplicati -ErrorAction SilentlyContinue)); '$installDir' exists: $(Test-Path $installDir)"
if ($trayRelated -or $agentRelated -or (Get-Service Duplicati -ErrorAction SilentlyContinue) -or (Test-Path $installDir)) {
    Say 'STOP: Duplicati is installed on this machine; nothing was changed.'
    $result | Set-Content -Path $out -Encoding utf8
    return
}

function Msi($arguments, $log) {
    $p = Start-Process msiexec.exe -ArgumentList "$arguments /l*v `"$log`"" -Wait -PassThru
    Say "  msiexec $($arguments.Split(' ')[0]) exit code: $($p.ExitCode)"
    $errors = Select-String -Path $log -Pattern 'Return value 3|Error 1060|Error 1939|Error 1720|Error 1721|Error 1722' -Encoding unicode | Select-Object -First 5
    Say "  error lines in log: $(@($errors).Count)$(if ($errors) { ' -> ' + (($errors | ForEach-Object { $_.Line.Trim() }) -join ' / ') })"
}

function ServiceState($label) {
    Say "[$label]"
    $svc = Get-Service Duplicati -ErrorAction SilentlyContinue
    Say "  service: $(if ($svc) { "$($svc.Status), StartType $($svc.StartType)" } else { '(none)' })"
    if ($svc) {
        $qc = (& sc.exe qc Duplicati | Select-String 'START_TYPE').Line.Trim()
        Say "  sc qc: $qc"
        $delayed = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati' -Name DelayedAutostart -ErrorAction SilentlyContinue).DelayedAutostart
        Say "  DelayedAutostart: $(if ($null -ne $delayed) { $delayed } else { '(none)' })"
    }
}

# A
$a = Join-Path $dir 'check-a'
New-Item -ItemType Directory -Force $a | Out-Null
Copy-Item $wixMsi (Join-Path $a 'gui.msi') -Force
'{"args":{"--example":"preload test"}}' | Set-Content -Path (Join-Path $a 'preload.json') -Encoding ascii -NoNewline
Say '=== A: WiX MSI, INSTALL_PRELOAD=true NOSCRIPT=true'
Msi "/i `"$(Join-Path $a 'gui.msi')`" /qn INSTALL_PRELOAD=true NOSCRIPT=true" (Join-Path $dir 'check-a-install.log')
$pre = Join-Path $installDir 'preload.json'
Say "  preload.json installed: $(Test-Path $pre)$(if (Test-Path $pre) { ', same content: ' + ((Get-Content $pre -Raw) -eq (Get-Content (Join-Path $a 'preload.json') -Raw)) })"
Say "  install folder SDDL: $((Get-Acl $installDir).Sddl)"
Say "  Duplicati.GUI.TrayIcon.exe installed: $(Test-Path (Join-Path $installDir 'Duplicati.GUI.TrayIcon.exe'))"
Msi "/x `"$(Join-Path $a 'gui.msi')`" /qn NOSCRIPT=true" (Join-Path $dir 'check-a-uninstall.log')
Say "  after uninstall: preload.json $(Test-Path $pre), install folder $(Test-Path $installDir)"

# B and C
foreach ($run in @(@('B', 'WiX', $wixMsi), @('C', 'wixl', $wixlMsi))) {
    $name, $tool, $msi = $run
    Say "=== ${name}: $tool MSI, ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature (scripts run)"
    Msi "/i `"$msi`" /qn ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature" (Join-Path $dir "check-$($name.ToLower())-install.log")
    ServiceState "$name installed"
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati' -Name DelayedAutostart -Value 0 -ErrorAction SilentlyContinue
    Say '  (DelayedAutostart set to 0 before the repair, to see whether the repair sets it again)'
    Msi "/fvomus `"$msi`" /qn" (Join-Path $dir "check-$($name.ToLower())-repair.log")
    ServiceState "$name repaired"
    Msi "/x `"$msi`" /qn" (Join-Path $dir "check-$($name.ToLower())-uninstall.log")
    ServiceState "$name uninstalled"
    Say "  install folder left: $(Test-Path $installDir); TrayIcon products installed: $(Related '{1C94BC5A-2BF2-4273-9D8F-2CB30E780D16}')"
}

# D: fix/msi-service-config-event (wixl, MsiServiceConfig Event 5 instead of 3), with a repair in between
$evMsi = Join-Path $dir 'wixlev-gui.msi'
Say '=== D: wixl MSI with Event 5, ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature, then repair, then uninstall'
Msi "/i `"$evMsi`" /qn ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature" (Join-Path $dir 'check-d-install.log')
ServiceState 'D installed'
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati' -Name DelayedAutostart -Value 0 -ErrorAction SilentlyContinue
Say '  (DelayedAutostart set to 0 before the repair, to see whether the repair sets it again)'
Msi "/fvomus `"$evMsi`" /qn" (Join-Path $dir 'check-d-repair.log')
ServiceState 'D repaired'
Msi "/x `"$evMsi`" /qn" (Join-Path $dir 'check-d-uninstall.log')
ServiceState 'D uninstalled'
Say "  install folder left: $(Test-Path $installDir); TrayIcon products installed: $(Related '{1C94BC5A-2BF2-4273-9D8F-2CB30E780D16}')"

$result | Set-Content -Path $out -Encoding utf8
"Written to $out"
