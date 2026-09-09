<#
  run3 の後片付けのやり直し（duplicati/duplicati#7804）。PowerShell 7 用。
  1 回目のアンインストールは、サービスが止まらず（エラー 1921）失敗した。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\cleanup2-7804.ps1

    1. C:\ProgramData\Duplicati を C:\ProgramData\Duplicati.before-7804 に一時的に退避する
       （アンインストールがサービスを一度起動するため。中身は変えない）。
    2. サービスが動いていたら止め、アンインストールする。
    3. 必ず: テストでできたフォルダーがあれば .\run3-programdata-2 へ移し、元のフォルダーの名前を戻す。
#>
$ErrorActionPreference = 'Stop'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$newMsi  = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
$pd      = 'C:\ProgramData\Duplicati'
$bk      = 'C:\ProgramData\Duplicati.before-7804'
$kept    = Join-Path $here 'run3-programdata-2'
$install = 'C:\Program Files\Duplicati 2'
$svcData = 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati'
$log     = Join-Path $here 'cleanup2.txt'
function L([string]$t) { $line = "$(Get-Date -Format 'HH:mm:ss') $t"; $line | Out-File -FilePath $log -Append -Encoding utf8; Write-Host $line -ForegroundColor Gray }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
if (Test-Path $bk) { throw "何も変えずに止めました: $bk がすでにあります。" }
if (Test-Path $kept) { throw "何も変えずに止めました: $kept がすでにあります。" }

if (Test-Path $log) { Remove-Item $log }
Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
$svc = Get-Service -Name Duplicati -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Stopped') {
    Say 'サービスを止めています...'
    Stop-Service -Name Duplicati -Force -ErrorAction SilentlyContinue
    Start-Sleep 5
    $pids = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Duplicati' } | ForEach-Object { $_.ProcessId }
    if ($pids) { $pids | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }; L "stopped Duplicati processes: $($pids -join ',')" }
}
if (Get-Process | Where-Object { $_.Name -match 'Duplicati' }) { throw '何も変えずに止めました: Duplicati のプログラムが止まりません。' }

$moved = $false; $before = $null
if (Test-Path $pd) {
    $before = (Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum)
    L "files in $pd before: $($before.Count), $($before.Sum) bytes"
    Rename-Item $pd 'Duplicati.before-7804'; $moved = $true
    L "renamed $pd -> $bk"
}
try {
    Say 'アンインストールしています（画面は出ません、1〜2 分かかります）...'
    $u = Start-Process msiexec.exe -ArgumentList "/x `"$newMsi`" /qn /l*v `"$here\logs\06-uninstall-retry.log`"" -Wait -PassThru
    L "uninstall exit code: $($u.ExitCode)"
    Get-Process | Where-Object { $_.Name -match 'Duplicati' } | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path $svcData) { Remove-Item $svcData -Recurse -Force; L "removed $svcData" }
    if (Test-Path 'HKLM:\SOFTWARE\DuplicatiTeam') { Remove-Item 'HKLM:\SOFTWARE\DuplicatiTeam' -Recurse -Force; L 'removed HKLM:\SOFTWARE\DuplicatiTeam' }
    cmdkey /delete:duplicati-trayicon-password 2>$null | Out-Null
    cmdkey /delete:duplicati-trayicon-hosturl 2>$null | Out-Null
} finally {
    $ErrorActionPreference = 'Continue'
    if (Test-Path $pd) { Move-Item $pd $kept; L "moved the test's $pd -> $kept" }
    if ($moved) {
        Rename-Item $bk 'Duplicati'
        $after = (Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum)
        L "renamed $bk back -> $pd; files: $($after.Count), $($after.Sum) bytes (before: $($before.Count), $($before.Sum))"
    }
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $installed = [bool](Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Duplicati' })
    L ("check: installed=$installed service=" + [bool](Get-Service -Name Duplicati -ErrorAction SilentlyContinue) + " installfolder=" + (Test-Path $install) + " $pd exists=" + (Test-Path $pd) + " $bk exists=" + (Test-Path $bk))
    if (-not $installed -and -not (Get-Service -Name Duplicati -ErrorAction SilentlyContinue)) { Say '片付けが終わりました。Duplicati は残っていません。' } else { Say 'まだ Duplicati が残っています。cleanup2.txt を見せてください。' 'Red' }
}
