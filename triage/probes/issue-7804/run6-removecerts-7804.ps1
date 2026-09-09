<#
  duplicati/duplicati#7804 の REMOVE-CERTS とログインの件の再現。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\run6-removecerts-7804.ps1

  報告者の手順どおりに進める:
    段階 1: 2.4.0.1 をサービス・TLS なしで入れる（インストーラーの画面）
    段階 2: 2.4.1.0 に更新し、TLS に「チェックを入れる」（インストーラーの画面）
    段階 3: Duplicati.WindowsService.exe REMOVE-CERTS を実行する（自動）
    段階 4: サービスの起動パラメーターに --webservice-password=（スクリプトが作ったテスト用の値）を付けて起動する（自動）
    段階 5: インストーラーで「Repair」する（インストーラーの画面）
  各段階のあと、HTTP / HTTPS の応答、トレイアイコンが覚えているパスワードでのログイン API の結果（応答コードだけ。
  パスワードは表示も記録もしない）、サービスのレジストリ値の名前、サーバー DB の場所、イベントログ、トレイアイコンの様子を記録する。
  インストーラーの画面は 3 回開く（画面ごとの操作は黄色の文字で表示）。質問はしない。
  C:\ProgramData\Duplicati は一時的に退避し、最後に必ず戻す。最後に全部アンインストールする。結果は .\run6.txt
#>
$ErrorActionPreference = 'Stop'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$oldMsi  = Join-Path $here 'duplicati-2.4.0.1_stable_2026-10-07-win-x64-gui.msi'
$newMsi  = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
$logs    = Join-Path $here 'logs'
$out     = Join-Path $here 'run6.txt'
$install = 'C:\Program Files\Duplicati 2'
$svcData = 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati'
$regTeam = 'HKLM:\SOFTWARE\DuplicatiTeam'
$regSvc  = 'HKLM:\SOFTWARE\DuplicatiTeam\Duplicati\Service'
$pd      = 'C:\ProgramData\Duplicati'
$bk      = 'C:\ProgramData\Duplicati.before-7804'
$kept    = Join-Path $here 'run6-programdata'
$menuLnk = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Duplicati.lnk'
# A throwaway test password for the start-parameter step; never shown or written to the log
$testPw  = -join ((1..24) | ForEach-Object { [char[]]'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789' | Get-Random })

Add-Type -Namespace Run6 -Name Cred -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern bool CredRead(string target, int type, int flags, out System.IntPtr credential);
[System.Runtime.InteropServices.DllImport("advapi32.dll")]
public static extern void CredFree(System.IntPtr buffer);
// Reads a generic credential's blob as text.
public static string ReadText(string target) {
    System.IntPtr p;
    if (!CredRead(target, 1, 0, out p)) return null;
    try {
        int size = System.Runtime.InteropServices.Marshal.ReadInt32(p, 32);
        System.IntPtr blob = System.Runtime.InteropServices.Marshal.ReadIntPtr(p, 40);
        if (size == 0 || blob == System.IntPtr.Zero) return "";
        var bytes = new byte[size];
        System.Runtime.InteropServices.Marshal.Copy(blob, bytes, 0, size);
        return System.Text.Encoding.Unicode.GetString(bytes);
    } finally { CredFree(p); }
}
'@

function W([string]$t) { $t | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function Installed {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    [bool](Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Duplicati' })
}
function Probe([string]$url) {
    try { $r = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -SkipCertificateCheck -SkipHttpErrorCheck -MaximumRedirection 0; "answers ($([int]$r.StatusCode))" } catch { "no answer" }
}
# Returns only the status code of the login API; the password is never written anywhere
function Login([string]$base, [string]$pw) {
    if ([string]::IsNullOrEmpty($pw)) { return 'no password' }
    try {
        $body = @{ Password = $pw; RememberMe = $false } | ConvertTo-Json
        $r = Invoke-WebRequest -Uri "$base/api/v1/auth/login" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 10 -SkipCertificateCheck -SkipHttpErrorCheck
        "$([int]$r.StatusCode)"
    } catch { 'no answer' }
}
function Wait-Service {
    for ($i = 0; $i -lt 90; $i++) {
        $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
        if ($s -and $s.Status -eq 'Running' -and (Get-NetTCPConnection -State Listen -LocalPort 8200 -ErrorAction SilentlyContinue)) { Start-Sleep 5; return }
        Start-Sleep 1
    }
}
function Msi([string]$label, [string]$arguments, [string[]]$hint) {
    Write-Host ''; Say "----- $label"
    foreach ($h in $hint) { Say "  $h" 'Yellow' }
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    $p = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    W ''; W "msiexec $label -> exit code $($p.ExitCode)"
}
function Snapshot([string]$label, [datetime]$since, [string[]]$extraPw = @()) {
    Say '  状態を記録しています（最大 90 秒）...' 'Gray'
    Wait-Service
    W "===== $label ($(Get-Date -Format s))"
    $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
    $http = Probe 'http://127.0.0.1:8200/'; $https = Probe 'https://127.0.0.1:8200/'
    W ("  service: " + $(if ($s) { $s.Status } else { 'not present' }) + "; http: $http; https: $https")
    $base = if ($https -like 'answers*') { 'https://127.0.0.1:8200' } else { 'http://127.0.0.1:8200' }
    $trayPw = [Run6.Cred]::ReadText('duplicati-trayicon-password')
    W ("  login at $base with the tray icon password: " + (Login $base $trayPw) + " (200 = accepted, 401 = rejected)")
    foreach ($e in $extraPw) { W ("  login at $base with the start-parameter test password: " + (Login $base $testPw)) }
    $hu = [Run6.Cred]::ReadText('duplicati-trayicon-hosturl')
    W ("  tray icon host url (wincred): " + $(if ($null -eq $hu) { 'not stored' } else { $hu }) + "; tray icon password stored: $($null -ne $trayPw)")
    try {
        $k = Get-Item $regSvc -ErrorAction Stop
        $vals = ($k.GetValueNames() | ForEach-Object { if ($_ -eq 'TlsCertsOption') { "TlsCertsOption=$($k.GetValue($_))" } else { $_ } }) -join ', '
        W "  service registry key: values [$vals]"
    } catch { W "  service registry key: $($_.Exception.Message)" }
    try { $st = Get-ItemProperty 'HKLM:\SOFTWARE\DuplicatiTeam\Duplicati\InstallState' -ErrorAction Stop; W ("  InstallState: " + (($st.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', ')) } catch { W '  InstallState: none' }
    foreach ($d in $pd, $svcData) {
        $f = Join-Path $d 'Duplicati-server.sqlite'
        if (Test-Path $f) { $i = Get-Item $f -Force; W "  server db: $f ($($i.Length) bytes, written $($i.LastWriteTime.ToString('s')))" } else { W "  server db: $f not present" }
    }
    try {
        $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Duplicati 2'; StartTime = $since } -ErrorAction Stop | Sort-Object TimeCreated)
        foreach ($e in $ev) { W ("  event $($e.TimeCreated.ToString('s')) $($e.LevelDisplayName): " + (($e.Message -replace '\s+', ' ').Substring(0, [Math]::Min(300, ($e.Message -replace '\s+', ' ').Length)))) }
    } catch { W "  events: none ($($_.Exception.Message))" }
    $sh = if (Test-Path $menuLnk) { (New-Object -ComObject WScript.Shell).CreateShortcut($menuLnk).Arguments } else { '(no shortcut)' }
    W "  start menu shortcut args: [$sh]"
}
function Test-Tray {
    Say '  トレイアイコンを自動で起動して、25 秒ほど様子を見ます（操作は不要です）...' 'Gray'
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    if (-not (Test-Path $menuLnk)) { W "  tray: no start menu shortcut"; return }
    Start-Process explorer.exe -ArgumentList "`"$menuLnk`""
    Start-Sleep 25
    $tp = @(Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue)
    if (-not $tp) { W "  tray: not running 25 seconds after the start"; return }
    foreach ($t in $tp) {
        $listen = (Get-NetTCPConnection -OwningProcess $t.Id -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $_.LocalPort } | Sort-Object -Unique) -join ','
        $conns = (Get-NetTCPConnection -OwningProcess $t.Id -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Listen' } | ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort)/$($_.State)" } | Sort-Object -Unique) -join ','
        $wins = (Get-Process -Id $t.Id -ErrorAction SilentlyContinue).MainWindowTitle
        W "  tray: pid=$($t.Id) own-listening-ports=[$listen] connections=[$conns] window=[$wins]"
    }
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
}
function Stop-Svc {
    $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
    if ($s -and $s.Status -ne 'Stopped') { Stop-Service -Name Duplicati -Force -NoWait -ErrorAction SilentlyContinue; for ($i = 0; $i -lt 30 -and (Get-Service -Name Duplicati).Status -ne 'Stopped'; $i++) { Start-Sleep 1 } }
    if ((Get-Service -Name Duplicati -ErrorAction SilentlyContinue).Status -ne 'Stopped') {
        Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'Duplicati.WindowsService.exe' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep 3
    }
}
function Uninstall-All {
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    Stop-Svc
    Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Duplicati' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    foreach ($m in $newMsi, $oldMsi) { if (Installed) { $p = Start-Process msiexec.exe -ArgumentList "/x `"$m`" /qn" -Wait -PassThru; W "  uninstall with $([IO.Path]::GetFileName($m)) -> $($p.ExitCode)" } }
    if (Test-Path $svcData) { Remove-Item $svcData -Recurse -Force }
    if (Test-Path $regTeam) { Remove-Item $regTeam -Recurse -Force }
    cmdkey /delete:duplicati-trayicon-password 2>$null | Out-Null
    cmdkey /delete:duplicati-trayicon-hosturl 2>$null | Out-Null
}

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
if (Installed) { throw '何も変えずに止めました: Duplicati が入っています。' }
if (Get-Service -Name Duplicati -ErrorAction SilentlyContinue) { throw '何も変えずに止めました: Duplicati のサービスがあります。' }
if (Test-Path $regTeam) { throw "何も変えずに止めました: $regTeam があります。" }
if (Test-Path $install) { throw "何も変えずに止めました: $install があります。" }
if (Test-Path $bk) { throw "何も変えずに止めました: $bk がすでにあります。" }
if (Test-Path $kept) { throw "何も変えずに止めました: $kept がすでにあります。" }
if (Get-Process | Where-Object { $_.Name -match 'Duplicati' }) { throw '何も変えずに止めました: Duplicati のプログラムが動いています。' }
if (cmdkey /list | Select-String -SimpleMatch 'duplicati-trayicon') { throw '何も変えずに止めました: トレイアイコンの資格情報（duplicati-trayicon-*）がすでにあります。' }

if (Test-Path $out) { Remove-Item $out }
New-Item -ItemType Directory -Force $logs, $kept | Out-Null
W "run6 started $(Get-Date -Format s), PowerShell $($PSVersionTable.PSVersion)"
$moved = $false; $before = $null
if (Test-Path $pd) {
    $before = Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum
    Rename-Item $pd 'Duplicati.before-7804'; $moved = $true
    W "moved $pd aside ($($before.Count) files, $($before.Sum) bytes)"
}
try {
    $t = Get-Date
    Msi '段階 1: 2.4.0.1 をサービスとして入れます（TLS なし）' "/i `"$oldMsi`" /l*v `"$logs\run6-1-install.log`"" @(
        '・「Install Duplicati as a Windows Service」にチェックを入れる',
        '・「Generate and use TLS (HTTPS) certificates」はチェックを外したまま',
        '・最後の画面の「Launch Duplicati now」はチェックを外す')
    Snapshot '1 after installing 2.4.0.1 without TLS' $t
    Test-Tray

    $t = Get-Date
    Msi '段階 2: 2.4.1.0 に更新します（TLS にチェックを入れる）' "/i `"$newMsi`" /l*v `"$logs\run6-2-upgrade-tls-on.log`"" @(
        '・オプションの画面で「Generate and use TLS (HTTPS) certificates」にチェックを入れる',
        '・ほかは変えずに進める',
        '・最後の画面の「Launch Duplicati now」はチェックを外す')
    Snapshot '2 after upgrading to 2.4.1.0 with TLS checked' $t
    Test-Tray

    Write-Host ''; Say '----- 段階 3: REMOVE-CERTS を実行します（自動、1 分ほど）'
    $t = Get-Date
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    $rc = & "$install\Duplicati.WindowsService.exe" REMOVE-CERTS 2>&1 | Out-String
    W ''; W "REMOVE-CERTS -> exit code $LASTEXITCODE"; foreach ($l in ($rc -split "`r?`n" | Where-Object { $_ })) { W "  | $l" }
    Snapshot '3 after REMOVE-CERTS' $t
    Test-Tray

    Write-Host ''; Say '----- 段階 4: 起動パラメーターにテスト用のパスワードを付けてサービスを起動します（自動）'
    $t = Get-Date
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    Stop-Svc
    # sc.exe start passes the arguments as start parameters, like the services.msc field
    $null = & sc.exe start Duplicati "--webservice-password=$testPw"
    W ''; W "sc start with --webservice-password -> exit code $LASTEXITCODE"
    Snapshot '4a after a start with --webservice-password in the start parameters' $t @('x')
    $t = Get-Date
    Stop-Svc; Start-Service -Name Duplicati
    Snapshot '4b after a normal restart' $t @('x')
    Test-Tray

    $t = Get-Date
    Msi '段階 5: 2.4.1.0 を修復します' "/i `"$newMsi`" /l*v `"$logs\run6-5-repair.log`"" @(
        '・最初の画面で「Repair」を選ぶ',
        '・ほかは変えずに進める（最後に「Launch Duplicati now」が出たら外す）')
    Snapshot '5 after Repair' $t @('x')
    Test-Tray
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say ''; Say '----- 後片付け: アンインストールして元のフォルダーを戻します（画面は出ません、1〜2 分かかります）'
    W ''; W '----- cleanup'
    Uninstall-All
    if (Test-Path $pd) { Move-Item $pd (Join-Path $kept 'programdata') }
    if ($moved) {
        Rename-Item $bk 'Duplicati'
        $after = Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum
        W "restored $pd ($($after.Count) files, $($after.Sum) bytes; before $($before.Count), $($before.Sum))"
        if ($after.Count -eq $before.Count -and $after.Sum -eq $before.Sum) { Say '元のフォルダーを戻しました（ファイル数・合計サイズとも元と同じ）。' } else { Say '元のフォルダーを戻しましたが、ファイル数か合計サイズが元と違います。run6.txt を見せてください。' 'Red' }
    }
    W "check: installed=$(Installed) service=$([bool](Get-Service -Name Duplicati -ErrorAction SilentlyContinue)) $pd=$(Test-Path $pd) $bk=$(Test-Path $bk) trayicon-creds=$([bool](cmdkey /list | Select-String -SimpleMatch 'duplicati-trayicon'))"
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。'
}
