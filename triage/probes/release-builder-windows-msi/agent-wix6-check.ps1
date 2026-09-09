# Run in an elevated (administrator) PowerShell.
# The two checks left for fix/release-builder-windows-msi, with MSIs built by WiX 6.0.2 on Windows:
#   J: the Agent MSI on a real machine
#      - install with a preload.json that points the agent registration at http://127.0.0.1:9/,
#        so the unregistered agent does not register this machine with the Duplicati console
#      - service Duplicati.Agent registered, running, delayed auto start; preload.json installed
#      - connections of the service process to anything other than this machine (expected: none)
#      - DelayedAutostart set to 0, repair, back to 1
#      - uninstall: service, preload.json and folder removed
#   K: the TrayIcon MSI from WiX 6.0.2, as case A of the earlier check (preload, folder ACL, uninstall)
# Everything is uninstalled at the end. Nothing else on the machine is changed.
# Expects build\packages (the ReleaseBuilder output) next to this script.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$packages = Join-Path $dir 'build\packages'
$agentMsi = (Get-ChildItem $packages -Filter '*-win-x64-agent.msi').FullName
$trayMsi = (Get-ChildItem $packages -Filter '*-win-x64-gui.msi').FullName
$out = Join-Path $dir 'agent-wix6-check-result.txt'
$agentDir = 'C:\Program Files\Duplicati Agent'
$trayDir = 'C:\Program Files\Duplicati 2'
$result = [System.Collections.Generic.List[string]]::new()
function Say($s) { $result.Add($s); $s }

Say "user: $env:USERDOMAIN\$env:USERNAME, elevated: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
Say "agent MSI: $(Split-Path -Leaf $agentMsi); tray MSI: $(Split-Path -Leaf $trayMsi)"
if ((Get-Service 'Duplicati', 'Duplicati.Agent' -ErrorAction SilentlyContinue) -or (Test-Path $agentDir) -or (Test-Path $trayDir)) {
    Say 'STOP: Duplicati or the Duplicati Agent is installed on this machine; nothing was changed.'
    $result | Set-Content -Path $out -Encoding utf8
    return
}

function Msi($arguments, $log) {
    $p = Start-Process msiexec.exe -ArgumentList "$arguments /l*v `"$log`"" -Wait -PassThru
    $errors = Select-String -Path $log -Pattern 'Return value 3|Error 1060|Error 1920|Error 1923|Error 1939|Error 1720|Error 1721|Error 1722' -Encoding unicode | Select-Object -First 3
    Say "  msiexec $($arguments.Split(' ')[0]) exit code: $($p.ExitCode); error lines: $(@($errors).Count)$(if ($errors) { ' -> ' + (($errors | ForEach-Object { $_.Line.Trim() }) -join ' / ') })"
}

function AgentState($label) {
    $svc = Get-Service 'Duplicati.Agent' -ErrorAction SilentlyContinue
    $line = "  [$label] service: $(if ($svc) { "$($svc.Status), StartType $($svc.StartType)" } else { '(none)' })"
    if ($svc) {
        $delayed = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati.Agent' -Name DelayedAutostart -ErrorAction SilentlyContinue).DelayedAutostart
        $line += "; DelayedAutostart: $(if ($null -ne $delayed) { $delayed } else { '(none)' })"
    }
    $line += "; folder: $(Test-Path $agentDir); preload.json: $(Test-Path (Join-Path $agentDir 'preload.json'))"
    Say $line
}

# J: Agent
Say '=== J: Agent MSI (WiX 6.0.2) with a preload.json'
$j = Join-Path $dir 'agent-case'
Remove-Item $j -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $j | Out-Null
Copy-Item $agentMsi (Join-Path $j 'agent.msi')
'{ "env": { "agent": { "DUPLICATI__REGISTER_REMOTE_CONTROL": "http://127.0.0.1:9/" } } }' | Set-Content (Join-Path $j 'preload.json') -Encoding ascii
$since = Get-Date
Msi "/i `"$(Join-Path $j 'agent.msi')`" /qn INSTALL_PRELOAD=true" (Join-Path $dir 'check-J-install.log')
Start-Sleep -Seconds 30
AgentState 'installed, 30 s later'
$installed = @(Get-ChildItem $agentDir -Recurse -File -ErrorAction SilentlyContinue).Count
Say "  files in the install folder: $installed"
$preload = Join-Path $agentDir 'preload.json'
if (Test-Path $preload) { Say "  preload.json same as the source: $((Get-FileHash $preload).Hash -eq (Get-FileHash (Join-Path $j 'preload.json')).Hash)" }
$svcPid = (Get-CimInstance Win32_Service -Filter "Name='Duplicati.Agent'").ProcessId
if ($svcPid) {
    $remote = @(Get-NetTCPConnection -OwningProcess $svcPid -ErrorAction SilentlyContinue | Where-Object { $_.RemoteAddress -notin @('127.0.0.1', '::1', '0.0.0.0', '::') })
    Say "  service process $svcPid, connections to other machines: $($remote.Count)$(if ($remote) { ' -> ' + (($remote | ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort) $($_.State)" }) -join ', ') })"
}
$events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Duplicati 2'; StartTime = $since } -ErrorAction SilentlyContinue | Sort-Object TimeCreated)
Say "  'Duplicati 2' log entries since the install: $($events.Count)"
$events | Select-Object -First 8 | ForEach-Object { Say "    $($_.TimeCreated.ToString('HH:mm:ss')) $($_.LevelDisplayName) $($_.ProviderName): $((($_.Message -replace '\s+', ' ')).Substring(0, [Math]::Min(170, ($_.Message -replace '\s+', ' ').Length)))" }
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati.Agent' -Name DelayedAutostart -Value 0 -ErrorAction SilentlyContinue
Say '  (DelayedAutostart set to 0 before the repair)'
Msi "/fvomus `"$(Join-Path $j 'agent.msi')`" /qn" (Join-Path $dir 'check-J-repair.log')
AgentState 'repaired'
Msi "/x `"$(Join-Path $j 'agent.msi')`" /qn" (Join-Path $dir 'check-J-uninstall.log')
AgentState 'uninstalled'

# K: TrayIcon, as case A
Say '=== K: TrayIcon MSI (WiX 6.0.2), INSTALL_PRELOAD=true NOSCRIPT=true'
$k = Join-Path $dir 'tray-case'
Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $k | Out-Null
Copy-Item $trayMsi (Join-Path $k 'gui.msi')
'{ "env": { "tray": { "DUPLICATI_TEST": "1" } } }' | Set-Content (Join-Path $k 'preload.json') -Encoding ascii
Msi "/i `"$(Join-Path $k 'gui.msi')`" /qn INSTALL_PRELOAD=true NOSCRIPT=true" (Join-Path $dir 'check-K-install.log')
Say "  preload.json installed: $(Test-Path (Join-Path $trayDir 'preload.json')); TrayIcon exe: $(Test-Path (Join-Path $trayDir 'Duplicati.GUI.TrayIcon.exe')); files: $(@(Get-ChildItem $trayDir -Recurse -File -ErrorAction SilentlyContinue).Count)"
Say "  install folder SDDL: $((Get-Acl $trayDir).Sddl)"
Msi "/x `"$(Join-Path $k 'gui.msi')`" /qn NOSCRIPT=true" (Join-Path $dir 'check-K-uninstall.log')
Say "  after uninstall: folder $(Test-Path $trayDir)"

Remove-Item $j, $k -Recurse -Force -ErrorAction SilentlyContinue
$result | Set-Content -Path $out -Encoding utf8
"Written to $out"
