<#
  duplicati/duplicati#7804 の修正の確認。PowerShell 7 用、画面なし・質問なしで全部自動。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\test-fix-7804.ps1

  公式の 2.4.1.0 の MSI と、ショートカットの引数の条件 2 つだけを直した MSI（duplicati-2.4.1.0-patched-7804.msi）で、
  同じ手順を順に行い、修復の前後のショートカットを比べる:
    1. サービス付きで画面なしインストール（インストーラーの画面で選ぶのと同じ機能）
    2. ショートカットを記録
    3. 画面なしで修復（REINSTALL=ALL REINSTALLMODE=ecmus）
    4. ショートカットとサービスの応答を記録
    5. サービスを止めてからアンインストール
  C:\ProgramData\Duplicati は一時的に C:\ProgramData\Duplicati.before-7804 に退避し、最後に必ず戻す。
  %LOCALAPPDATA%\Duplicati（利用者自身のデータ）には触れない。結果は .\fix-result.txt
#>
$ErrorActionPreference = 'Stop'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$msis    = [ordered]@{
    'original' = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
    'patched'  = Join-Path $here 'duplicati-2.4.1.0-patched-7804.msi'
}
$logs    = Join-Path $here 'logs'
$out     = Join-Path $here 'fix-result.txt'
$install = 'C:\Program Files\Duplicati 2'
$svcData = 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati'
$regTeam = 'HKLM:\SOFTWARE\DuplicatiTeam'
$pd      = 'C:\ProgramData\Duplicati'
$bk      = 'C:\ProgramData\Duplicati.before-7804'
$kept    = Join-Path $here 'fix-programdata'
$features = 'DuplicatiCore,DuplicatiServiceFeature,DuplicatiDesktopShortCutFeature,DuplicatiProgramMenuShortCutFeature,DuplicatiStartupShortCutFeature'

function W([string]$t) { $t | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function Installed {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    [bool](Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Duplicati' })
}
function Msi([string]$label, [string]$arguments) {
    $p = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    W "msiexec $label -> exit code $($p.ExitCode)"
    return $p.ExitCode
}
function Shortcuts([string]$label) {
    $links = Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu', 'C:\Users\Public\Desktop' -Recurse -Filter 'Duplicati*.lnk' -ErrorAction SilentlyContinue
    if (-not $links) { W "  $label shortcuts: none"; return }
    foreach ($lnk in $links) { $sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk.FullName); W ("  $label $($lnk.FullName.Replace('C:\ProgramData\Microsoft\Windows\Start Menu\Programs\', '')): args=[" + $sh.Arguments + ']') }
}
function ServiceState([string]$label) {
    Start-Sleep 15
    $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
    $http = try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8200/' -Method Head -TimeoutSec 5 -SkipHttpErrorCheck -MaximumRedirection 0; "answers ($([int]$r.StatusCode))" } catch { "no answer ($($_.Exception.GetType().Name))" }
    W "  $label service: $(if ($s) { $s.Status } else { 'not present' }); http 8200: $http"
}
function LogLines([string]$log) {
    Select-String -Path $log -Encoding Unicode -Pattern 'Feature: DuplicatiServiceFeature', '(Doing|Skipping) action: (SetNoHostedServerArg|ClearNoHostedServerArg)', 'PROPERTY CHANGE: .*NOHOSTEDSERVERARG' |
        ForEach-Object { W ('    ' + ($_.Line.Trim() -replace '^MSI \(s\) \([0-9A-F:]+\) ', '')) }
}
function StopService {
    Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
    $s = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
    if ($s -and $s.Status -ne 'Stopped') {
        Stop-Service -Name Duplicati -Force -NoWait -ErrorAction SilentlyContinue
        for ($i = 0; $i -lt 20 -and (Get-Service -Name Duplicati).Status -ne 'Stopped'; $i++) { Start-Sleep 1 }
    }
    $left = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Duplicati' }
    if ($left) { $left | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; W "  stopped Duplicati processes that did not stop: $(($left | ForEach-Object { $_.Name }) -join ', ')" }
}

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
foreach ($m in $msis.Values) { if (-not (Test-Path $m)) { throw "MSI がありません: $m" } }
if (Installed) { throw '何も変えずに止めました: Duplicati が入っています。' }
if (Get-Service -Name Duplicati -ErrorAction SilentlyContinue) { throw '何も変えずに止めました: Duplicati のサービスがあります。' }
if (Test-Path $regTeam) { throw "何も変えずに止めました: $regTeam があります。" }
if (Test-Path $install) { throw "何も変えずに止めました: $install があります。" }
if (Test-Path $bk) { throw "何も変えずに止めました: $bk がすでにあります。" }
if (Test-Path $kept) { throw "何も変えずに止めました: $kept がすでにあります。" }
if (Get-Process | Where-Object { $_.Name -match 'Duplicati' }) { throw '何も変えずに止めました: Duplicati のプログラムが動いています。' }

if (Test-Path $out) { Remove-Item $out }
New-Item -ItemType Directory -Force $logs, $kept | Out-Null
W "test-fix-7804 started $(Get-Date -Format s), PowerShell $($PSVersionTable.PSVersion)"
$moved = $false; $before = $null
if (Test-Path $pd) {
    $before = Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum
    Rename-Item $pd 'Duplicati.before-7804'; $moved = $true
    W "moved $pd aside ($($before.Count) files, $($before.Sum) bytes)"
}
try {
    foreach ($name in $msis.Keys) {
        $msi = $msis[$name]
        Write-Host ''
        Say "===== $name の MSI で確認します（画面は出ません、数分かかります）"
        W ''; W "===== $name ($([IO.Path]::GetFileName($msi)))"
        Say '  1. サービス付きでインストール...'
        $rc = Msi '1 install' "/i `"$msi`" /qn ADDLOCAL=$features /l*v `"$logs\fix-$name-1-install.log`""
        if ($rc -ne 0) { throw "$name のインストールが失敗しました（終了コード $rc）" }
        Shortcuts 'after install:'
        LogLines "$logs\fix-$name-1-install.log"
        Say '  2. 修復...'
        $rc = Msi '2 repair' "/i `"$msi`" /qn REINSTALL=ALL REINSTALLMODE=ecmus /l*v `"$logs\fix-$name-2-repair.log`""
        Shortcuts 'after repair:'
        LogLines "$logs\fix-$name-2-repair.log"
        ServiceState 'after repair:'
        Say '  3. アンインストール...'
        StopService
        $rc = Msi '3 uninstall' "/x `"$msi`" /qn /l*v `"$logs\fix-$name-3-uninstall.log`""
        StopService
        if (Test-Path $svcData) { Remove-Item $svcData -Recurse -Force }
        if (Test-Path $regTeam) { Remove-Item $regTeam -Recurse -Force }
        cmdkey /delete:duplicati-trayicon-password 2>$null | Out-Null
        cmdkey /delete:duplicati-trayicon-hosturl 2>$null | Out-Null
        if (Test-Path $pd) { Move-Item $pd (Join-Path $kept $name) }
        W "  after uninstall: installed=$(Installed) service=$([bool](Get-Service -Name Duplicati -ErrorAction SilentlyContinue)) folder=$(Test-Path $install)"
        if (Installed) { throw "$name のアンインストールが終わっていません" }
    }
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    if (Installed) {
        Say '片付けのためアンインストールしています...' 'Yellow'
        StopService
        foreach ($m in $msis.Values) { if (Installed) { Msi 'cleanup uninstall' "/x `"$m`" /qn" | Out-Null } }
        if (Test-Path $regTeam) { Remove-Item $regTeam -Recurse -Force }
        if (Test-Path $svcData) { Remove-Item $svcData -Recurse -Force }
    }
    if (Test-Path $pd) { Move-Item $pd (Join-Path $kept 'leftover') }
    if ($moved) {
        Rename-Item $bk 'Duplicati'
        $after = Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum
        W "restored $pd ($($after.Count) files, $($after.Sum) bytes; before $($before.Count), $($before.Sum))"
        if ($after.Count -eq $before.Count -and $after.Sum -eq $before.Sum) { Say '元のフォルダーを戻しました（ファイル数・合計サイズとも元と同じ）。' } else { Say '元のフォルダーを戻しましたが、ファイル数か合計サイズが元と違います。fix-result.txt を見せてください。' 'Red' }
    }
    W "check: installed=$(Installed) service=$([bool](Get-Service -Name Duplicati -ErrorAction SilentlyContinue)) $pd=$(Test-Path $pd) $bk=$(Test-Path $bk)"
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。'
}
