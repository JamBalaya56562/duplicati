<#
  duplicati/duplicati#7804 の修正の確認。run4-tls-7804.ps1 と同じ手順を、2.4.1.0 だけ修正を入れた MSI
  （duplicati-2.4.1.0-patched-7804-tls.msi、トレイアイコンの接続先を TLS に合わせる処理を追加）で行う。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\run4-tls-7804.ps1

  シナリオ 1（報告）: 2.4.0.1 をサービス・TLS なしで入れる → 2.4.1.0 に更新し、TLS に「チェックを入れる」
  シナリオ 2（逆）  : 2.4.1.0 をサービス・TLS ありで新しく入れる → 「Change」で TLS の「チェックを外す」
  各段階のあと、サービスが HTTP・HTTPS のどちらで応答するか、トレイアイコンが覚えている接続先
  （duplicati-trayicon-hosturl の値だけ。パスワードは読まない）、トレイアイコンの様子を自動で記録する。
  インストーラーの画面は 4 回開く（画面ごとの操作は黄色の文字で表示）。質問はしない。
  C:\ProgramData\Duplicati は一時的に退避し、最後に必ず戻す。最後に全部アンインストールする。結果は .\run4.txt
#>
$ErrorActionPreference = 'Stop'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$oldMsi  = Join-Path $here 'duplicati-2.4.0.1_stable_2026-10-07-win-x64-gui.msi'
$newMsi  = Join-Path $here 'duplicati-2.4.1.0-patched-7804-tls.msi'
$logs    = Join-Path $here 'logs'
$out     = Join-Path $here 'run5.txt'
$install = 'C:\Program Files\Duplicati 2'
$svcData = 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati'
$regTeam = 'HKLM:\SOFTWARE\DuplicatiTeam'
$pd      = 'C:\ProgramData\Duplicati'
$bk      = 'C:\ProgramData\Duplicati.before-7804'
$kept    = Join-Path $here 'run5-programdata'
$menuLnk = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Duplicati.lnk'

Add-Type -Namespace Run4 -Name Cred -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern bool CredRead(string target, int type, int flags, out System.IntPtr credential);
[System.Runtime.InteropServices.DllImport("advapi32.dll")]
public static extern void CredFree(System.IntPtr buffer);
// Reads a generic credential's blob as text. Used only for duplicati-trayicon-hosturl.
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
function Msi([string]$label, [string]$arguments, [string[]]$hint) {
    Write-Host ''; Say "----- $label"
    foreach ($h in $hint) { Say "  $h" 'Yellow' }
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    $p = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    W ''; W "msiexec $label -> exit code $($p.ExitCode)"
}
function Snapshot([string]$label) {
    Say '  状態を記録しています（最大 90 秒）...' 'Gray'
    for ($i = 0; $i -lt 90; $i++) {
        $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
        if ($s -and $s.Status -eq 'Running' -and (Get-NetTCPConnection -State Listen -LocalPort 8200 -ErrorAction SilentlyContinue)) { Start-Sleep 5; break }
        Start-Sleep 1
    }
    W "===== $label ($(Get-Date -Format s))"
    $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
    W ("  service: " + $(if ($s) { $s.Status } else { 'not present' }) + "; http: " + (Probe 'http://127.0.0.1:8200/') + "; https: " + (Probe 'https://127.0.0.1:8200/'))
    $hu = [Run4.Cred]::ReadText('duplicati-trayicon-hosturl')
    $pw = [bool](cmdkey /list | Select-String -SimpleMatch 'duplicati-trayicon-password')
    W ("  tray icon host url (wincred): " + $(if ($null -eq $hu) { 'not stored (the tray icon uses http://127.0.0.1:8200)' } else { $hu }) + "; tray icon password stored: $pw")
    try { $st = Get-ItemProperty 'HKLM:\SOFTWARE\DuplicatiTeam\Duplicati\InstallState' -ErrorAction Stop; W ("  InstallState: " + (($st.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', ')) } catch { W '  InstallState: none' }
    $sh = if (Test-Path $menuLnk) { (New-Object -ComObject WScript.Shell).CreateShortcut($menuLnk).Arguments } else { '(no shortcut)' }
    W "  start menu shortcut args: [$sh]"
}
function Test-Tray([string]$label) {
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
function Uninstall-All {
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
    if ($s -and $s.Status -ne 'Stopped') { Stop-Service -Name Duplicati -Force -NoWait -ErrorAction SilentlyContinue; for ($i = 0; $i -lt 20 -and (Get-Service -Name Duplicati).Status -ne 'Stopped'; $i++) { Start-Sleep 1 } }
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
W "run5 started $(Get-Date -Format s), PowerShell $($PSVersionTable.PSVersion)"
$moved = $false; $before = $null
if (Test-Path $pd) {
    $before = Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum
    Rename-Item $pd 'Duplicati.before-7804'; $moved = $true
    W "moved $pd aside ($($before.Count) files, $($before.Sum) bytes)"
}
try {
    W ''; W '########## Scenario 1 (the report): HTTP service, then an upgrade with TLS checked'
    Msi 'シナリオ 1 / 段階 1: 2.4.0.1 をサービスとして入れます（TLS なし）' "/i `"$oldMsi`" /l*v `"$logs\run5-1a-install.log`"" @(
        '・「Install Duplicati as a Windows Service」にチェックを入れる',
        '・「Generate and use TLS (HTTPS) certificates」はチェックを外したまま',
        '・最後の画面の「Launch Duplicati now」はチェックを外す')
    Snapshot '1a after installing 2.4.0.1 without TLS'
    Test-Tray '1a'
    Msi 'シナリオ 1 / 段階 2: 2.4.1.0 に更新します（TLS にチェックを入れる）' "/i `"$newMsi`" /l*v `"$logs\run5-1b-upgrade-tls-on.log`"" @(
        '・オプションの画面で「Generate and use TLS (HTTPS) certificates」にチェックを入れる（ここが報告の操作です）',
        '・ほかは変えずに進める',
        '・最後の画面の「Launch Duplicati now」はチェックを外す')
    Snapshot '1b after upgrading to 2.4.1.0 with TLS checked'
    Test-Tray '1b'

    Say ''; Say '----- シナリオ 1 が終わったので、いったんアンインストールします（画面は出ません）'
    W ''; W '----- uninstall between the scenarios'
    Uninstall-All
    if (Test-Path $pd) { Move-Item $pd (Join-Path $kept 'scenario1') }

    W ''; W '########## Scenario 2 (the reverse): a fresh install with TLS, then Change with TLS unchecked'
    Msi 'シナリオ 2 / 段階 1: 2.4.1.0 をサービス・TLS ありで入れます' "/i `"$newMsi`" /l*v `"$logs\run5-2a-install-tls.log`"" @(
        '・「Install Duplicati as a Windows Service」にチェックを入れる',
        '・「Generate and use TLS (HTTPS) certificates」にチェックを入れる',
        '・最後の画面の「Launch Duplicati now」はチェックを外す')
    Snapshot '2a after installing 2.4.1.0 with TLS'
    Test-Tray '2a'
    Msi 'シナリオ 2 / 段階 2: Change で TLS のチェックを外します' "/i `"$newMsi`" /l*v `"$logs\run5-2b-change-tls-off.log`"" @(
        '・最初の画面で「Change」を選ぶ',
        '・オプションの画面で「Generate and use TLS (HTTPS) certificates」のチェックを外す',
        '・ほかは変えずに進める（最後に「Launch Duplicati now」が出たら外す）')
    Snapshot '2b after Change with TLS unchecked'
    Test-Tray '2b'
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say ''; Say '----- 後片付け: アンインストールして元のフォルダーを戻します（画面は出ません、1〜2 分かかります）'
    W ''; W '----- cleanup'
    Uninstall-All
    if (Test-Path $pd) { Move-Item $pd (Join-Path $kept 'scenario2') }
    if ($moved) {
        Rename-Item $bk 'Duplicati'
        $after = Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum
        W "restored $pd ($($after.Count) files, $($after.Sum) bytes; before $($before.Count), $($before.Sum))"
        if ($after.Count -eq $before.Count -and $after.Sum -eq $before.Sum) { Say '元のフォルダーを戻しました（ファイル数・合計サイズとも元と同じ）。' } else { Say '元のフォルダーを戻しましたが、ファイル数か合計サイズが元と違います。run5.txt を見せてください。' 'Red' }
    }
    W "check: installed=$(Installed) service=$([bool](Get-Service -Name Duplicati -ErrorAction SilentlyContinue)) $pd=$(Test-Path $pd) $bk=$(Test-Path $bk) trayicon-creds=$([bool](cmdkey /list | Select-String -SimpleMatch 'duplicati-trayicon'))"
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。'
}
