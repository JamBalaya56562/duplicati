<#
  duplicati/duplicati#7804 の再現（このフォルダーの公式の MSI を使う）。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\repro-7804.ps1
  通常は run3-7804.ps1 から呼ばれる。

  段階（msiexec の詳しいログは .\logs に出る）:
    1. 2.4.0.1 をサービスとして HTTP で入れる
    2. 2.4.1.0 に更新する
    3. Duplicati.WindowsService.exe REMOVE-CERTS
    4. 2.4.1.0 の MSI で修復する
    5. アンインストールと後片付け（-SkipCleanup のときは行わない）
  各段階のあと、トレイアイコンをショートカットから自動で起動して様子を記録する（質問はしない）。

  安全のため:
    * Duplicati が入っている、サービスがある、HKLM\SOFTWARE\DuplicatiTeam がある、
      C:\Program Files\Duplicati 2 がある、のどれかなら何もせずに止まる。
    * %LOCALAPPDATA%\Duplicati（利用者自身のデータ）には触れない。
#>
param([switch]$SkipCleanup)

$ErrorActionPreference = 'Stop'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$oldMsi  = Join-Path $here 'duplicati-2.4.0.1_stable_2026-10-07-win-x64-gui.msi'
$newMsi  = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
$logs    = Join-Path $here 'logs'
$result  = Join-Path $here 'result.txt'
$install = 'C:\Program Files\Duplicati 2'
$svcData = 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati'
$regTeam = 'HKLM:\SOFTWARE\DuplicatiTeam'
$menuLnk = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Duplicati.lnk'

function Out-Result([string]$text) { $text | Out-File -FilePath $result -Append -Encoding utf8 }
function Say([string]$text, [string]$color = 'Cyan') { Write-Host $text -ForegroundColor $color }

function Assert-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
}

function Get-InstalledDuplicati {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Duplicati' }
}

# Any answer, even an error status, means the server speaks that protocol. The certificate is self-signed, so it is not checked.
function Test-Url([string]$url) {
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -SkipCertificateCheck -SkipHttpErrorCheck -MaximumRedirection 0 -ErrorAction Stop
        return "answers ($([int]$r.StatusCode))"
    } catch {
        return "no answer ($($_.Exception.GetType().Name): $($_.Exception.Message -replace '\s+', ' '))"
    }
}

function Wait-Service([int]$seconds = 90) {
    if (-not (Get-Service -Name Duplicati -ErrorAction SilentlyContinue)) { return }
    for ($i = 0; $i -lt $seconds; $i++) {
        $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
        if ($s -and $s.Status -eq 'Running' -and (Get-NetTCPConnection -State Listen -LocalPort 8200 -ErrorAction SilentlyContinue)) { Start-Sleep 5; return }
        Start-Sleep 1
    }
}

function Snapshot([string]$label) {
    Say '  状態を記録しています（最大 90 秒）...' 'Gray'
    Wait-Service
    Out-Result ''
    Out-Result "===== $label  ($(Get-Date -Format s))"
    $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
    Out-Result ("service: " + $(if ($s) { "$($s.Status), start=$($s.StartType)" } else { 'not present' }))
    Out-Result ("installed: " + ((Get-InstalledDuplicati | ForEach-Object { "$($_.DisplayName) $($_.DisplayVersion)" }) -join '; '))
    Out-Result ("http://127.0.0.1:8200  -> " + (Test-Url 'http://127.0.0.1:8200/'))
    Out-Result ("https://127.0.0.1:8200 -> " + (Test-Url 'https://127.0.0.1:8200/'))
    foreach ($k in 'HKLM:\SOFTWARE\DuplicatiTeam\Duplicati\InstallState', 'HKLM:\SOFTWARE\DuplicatiTeam\Duplicati\Service') {
        try {
            $p = Get-ItemProperty $k -ErrorAction Stop
            $vals = $p.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' -and $_.Name -notmatch 'Password' } | ForEach-Object { "$($_.Name)=$($_.Value)" }
            Out-Result ("$k : " + ($vals -join ', '))
        } catch { Out-Result ("$k : " + $_.Exception.Message) }
    }
    $links = Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu', 'C:\Users\Public\Desktop' -Recurse -Filter 'Duplicati*.lnk' -ErrorAction SilentlyContinue
    if (-not $links) { Out-Result 'shortcuts: none' }
    foreach ($lnk in $links) { $sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk.FullName); Out-Result ("shortcut $($lnk.FullName): `"$($sh.TargetPath)`" $($sh.Arguments)") }
    # Only the names of the stored credentials, never their values
    $names = cmdkey /list | Select-String -Pattern 'duplicati' | ForEach-Object { ($_.Line -replace '^\s*\S+:\s*', '').Trim() }
    Out-Result ("wincred entries named duplicati: " + $(if ($names) { $names -join ', ' } else { 'none' }))
}

# Starts the tray icon from the Start menu shortcut, unelevated as a click would, and records what it does
function Test-Tray([string]$label) {
    Say '  トレイアイコンを自動で起動して、20 秒ほど様子を見ます（操作は不要です）...' 'Gray'
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    if (-not (Test-Path $menuLnk)) { Out-Result "tray ($label): start menu shortcut missing"; return }
    # explorer.exe opens the shortcut as the signed-in user without elevation, like a click in the Start menu
    Start-Process explorer.exe -ArgumentList "`"$menuLnk`""
    Start-Sleep 20
    $tp = @(Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue)
    if (-not $tp) { Out-Result "tray ($label): not running 20 seconds after the start"; Say '  → トレイアイコンは起動していません。' 'Yellow'; return }
    foreach ($t in $tp) {
        $ci = Get-CimInstance Win32_Process -Filter "ProcessId=$($t.Id)"
        $owner = Invoke-CimMethod -InputObject $ci -MethodName GetOwner -ErrorAction SilentlyContinue
        $listen = (Get-NetTCPConnection -OwningProcess $t.Id -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $_.LocalPort } | Sort-Object -Unique) -join ','
        $conns = (Get-NetTCPConnection -OwningProcess $t.Id -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Listen' } | ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort)/$($_.State)" } | Sort-Object -Unique) -join ','
        $title = (Get-Process -Id $t.Id -ErrorAction SilentlyContinue).MainWindowTitle
        Out-Result ("tray ($label): pid=$($t.Id) user=$($owner.User) commandline=[$($ci.CommandLine)] own-listening-ports=[$listen] connections=[$conns] window=[$title]")
        if ($listen) { Say "  → トレイアイコンが自分でサーバーを立てています（ポート $listen）。サービスには繋いでいません。" 'Yellow' }
        elseif ($title) { Say "  → トレイアイコンが「$title」という画面を出しています。" 'Yellow' }
        else { Say '  → トレイアイコンは動いています。' 'Gray' }
    }
}

function Summarize-Log([string]$log) {
    if (-not (Test-Path $log)) { Out-Result "  (no log $log)"; return }
    $patterns = 'Feature: DuplicatiTlsCertsFeature', 'Feature: DuplicatiServiceFeature',
                'Property\([SC]\): (INSTALL_TLS_CERTS|PREVIOUS_USER_CERTS_INSTALLED|PREVIOUS_SERVICE_CERTS_INSTALLED|PREVIOUS_SERVICE_INSTALLED|LAUNCH_AS_SERVICE|INSTALLASSERVICE|UPGRADE_DROP_SERVICE_CERTS|PREVIOUSVERSIONSINSTALLED|NOHOSTEDSERVERARG|UILevel) =',
                'Doing action: (Set_INSTALL_TLS_CERTS|InstallTlsCerts|UninstallRemoveTlsCerts|UpgradeRemoveTlsCerts|WriteUpgradeSentinel|RemoveExistingProducts|ReconcileTlsCertMarkers|SetInitPassword|StoreTrayIconValues|SetNoHostedServerArg|ClearNoHostedServerArg)',
                'Skipping action: (SetNoHostedServerArg|ClearNoHostedServerArg|StoreTrayIconValues|SetInitPassword)',
                'Ignoring disallowed property', 'PROPERTY CHANGE: .*(INSTALL_TLS_CERTS|PREVIOUS_SERVICE_CERTS_INSTALLED|PREVIOUS_USER_CERTS_INSTALLED)'
    Out-Result "  --- $([IO.Path]::GetFileName($log))"
    Select-String -Path $log -Pattern $patterns -Encoding Unicode | ForEach-Object { Out-Result ("  " + $_.Line.Trim()) }
}

function Run-Msi([string]$label, [string]$arguments, [string[]]$hint) {
    Write-Host ''
    Say "----- $label"
    foreach ($h in $hint) { Say "  $h" 'Yellow' }
    $p = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    Out-Result ''
    Out-Result "msiexec $arguments -> exit code $($p.ExitCode)"
}

# ---------------------------------------------------------------- preflight
Assert-Admin
foreach ($f in $oldMsi, $newMsi) { if (-not (Test-Path $f)) { throw "MSI がありません: $f" } }
$existing = @()
if (Get-InstalledDuplicati) { $existing += 'Duplicati が入っています' }
if (Get-Service -Name Duplicati -ErrorAction SilentlyContinue) { $existing += 'Duplicati のサービスがあります' }
if (Test-Path $regTeam) { $existing += "$regTeam があります" }
if (Test-Path $install) { $existing += "$install があります" }
if ($existing.Count -gt 0) { throw ('何も変えずに止めました: ' + ($existing -join '、')) }
$svcDataExisted = Test-Path $svcData
$wincredBefore  = (cmdkey /list | Select-String -SimpleMatch 'duplicati-trayicon' | Measure-Object).Count
New-Item -ItemType Directory -Force $logs | Out-Null
if (Test-Path $result) { $keep = Join-Path $here ('run-' + (Get-Date -Format 'HHmmss')); New-Item -ItemType Directory $keep | Out-Null; Move-Item $result $keep; Get-ChildItem $logs -File | Move-Item -Destination $keep }
Out-Result "repro-7804 started $(Get-Date -Format s) on $([Environment]::OSVersion.VersionString), PowerShell $($PSVersionTable.PSVersion)"
Out-Result "service data folder existed before: $svcDataExisted; wincred trayicon entries before: $wincredBefore"

# ---------------------------------------------------------------- 1. 2.4.0.1 over HTTP
Run-Msi '段階 1/4: 2.4.0.1 をサービスとして入れます' "/i `"$oldMsi`" /l*v `"$logs\01-install-2.4.0.1.log`"" @(
    'インストーラーの画面が開きます。次のとおり操作してください:',
    '・「Install Duplicati as a Windows Service」にチェックを入れる',
    '・「Generate and use TLS (HTTPS) certificates」はチェックを外したまま',
    '・最後の画面の「Launch Duplicati now」はチェックを外す')
Snapshot 'after 1 (2.4.0.1 installed)'
Summarize-Log "$logs\01-install-2.4.0.1.log"
Test-Tray 'after 1 (install)'

# ---------------------------------------------------------------- 2. upgrade to 2.4.1.0
Run-Msi '段階 2/4: 2.4.1.0 に更新します' "/i `"$newMsi`" /l*v `"$logs\02-upgrade-2.4.1.0.log`"" @(
    'インストーラーの画面が開きます。何も変えずに「Next」で進めてください。',
    '・最後の画面の「Launch Duplicati now」はチェックを外す')
Snapshot 'after 2 (upgraded to 2.4.1.0)'
Summarize-Log "$logs\02-upgrade-2.4.1.0.log"
Test-Tray 'after 2 (upgrade)'

# ---------------------------------------------------------------- 3. REMOVE-CERTS
Write-Host ''; Say '----- 段階 3/4: REMOVE-CERTS を実行します（操作は不要です）'
Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
$svcExe = Join-Path $install 'Duplicati.WindowsService.exe'
$out = & $svcExe REMOVE-CERTS 2>&1 | Out-String
Out-Result ''; Out-Result "Duplicati.WindowsService.exe REMOVE-CERTS -> exit $LASTEXITCODE"; Out-Result $out.Trim()
Snapshot 'after 3 (REMOVE-CERTS)'
Test-Tray 'after 3 (REMOVE-CERTS)'

# ---------------------------------------------------------------- 4. repair
Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
Run-Msi '段階 4/4: 2.4.1.0 の MSI で修復します' "/i `"$newMsi`" /l*v `"$logs\04-repair.log`"" @(
    'インストーラーの画面が開きます。「Repair」を選んでください。',
    '・最後に「Launch Duplicati now」が出たらチェックを外す')
Snapshot 'after 4 (repair)'
Summarize-Log "$logs\04-repair.log"
Test-Tray 'after 4 (repair)'

# ---------------------------------------------------------------- 5. cleanup
Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
if ($SkipCleanup) { Out-Result ''; Out-Result 'cleanup skipped (-SkipCleanup)'; Say '再現の段階は終わりました。'; return }
Say '----- 後片付け: アンインストールします（画面は出ません、1〜2 分かかります）'
Run-Msi '5. アンインストール' "/x `"$newMsi`" /qn /l*v `"$logs\05-uninstall.log`"" @()
if (-not $svcDataExisted -and (Test-Path $svcData)) { Remove-Item $svcData -Recurse -Force; Out-Result "removed $svcData" }
if (Test-Path $regTeam) { Remove-Item $regTeam -Recurse -Force; Out-Result "removed $regTeam" }
if ($wincredBefore -eq 0) { cmdkey /delete:duplicati-trayicon-password 2>$null | Out-Null; cmdkey /delete:duplicati-trayicon-hosturl 2>$null | Out-Null }
if (Test-Path $install) { Out-Result "left over: $install (not removed, check it)" }
Snapshot 'after 5 (uninstalled)'
Out-Result ''; Out-Result "done $(Get-Date -Format s)."
Say '終わりました。'
