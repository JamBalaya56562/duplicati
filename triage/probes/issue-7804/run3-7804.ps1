<#
  duplicati/duplicati#7804 の 3 回目の再現。サービスのデータのフォルダーを一時的に退避して行う。PowerShell 7 用。
  C:\ProgramData\Duplicati には新しい版の Duplicati のデータベース（バージョン 13）があり、2.4.1.0 はそれを開けないため、
  1・2 回目はサービスが起動の数秒後に止まっていた。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\run3-7804.ps1

    1. C:\ProgramData\Duplicati の名前を C:\ProgramData\Duplicati.before-7804 に変える（中身は変えない）。
    2. repro-7804.ps1 -SkipCleanup を実行する。
    3. 2 で失敗しても必ず: cleanup-7804.ps1 を実行し、テストでできたフォルダーを .\run3-programdata へ移し、
       C:\ProgramData\Duplicati.before-7804 の名前を C:\ProgramData\Duplicati に戻す。
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$pd   = 'C:\ProgramData\Duplicati'
$bk   = 'C:\ProgramData\Duplicati.before-7804'
$kept = Join-Path $here 'run3-programdata'
$log  = Join-Path $here 'run3.txt'
function L([string]$t) { "$(Get-Date -Format 'HH:mm:ss') $t" | Out-File -FilePath $log -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください（pwsh -ExecutionPolicy Bypass -File .\run3-7804.ps1）。' }
$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
if (Test-Path $bk) { throw "何も変えずに止めました: $bk がすでにあります。先に $pd に戻してください。" }
if (Test-Path $kept) { throw "何も変えずに止めました: $kept がすでにあります。名前を変えるか消してください。" }
if (Get-Process | Where-Object { $_.Name -match 'Duplicati' }) { throw '何も変えずに止めました: Duplicati のプログラムが動いています。先に終了してください。' }
if (Get-Service -Name Duplicati -ErrorAction SilentlyContinue) { throw '何も変えずに止めました: Duplicati のサービスがあります。先に cleanup-7804.ps1 を実行してください。' }

if (Test-Path $log) { Remove-Item $log }
$moved = $false
$before = $null
if (Test-Path $pd) {
    $before = (Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum)
    L "files in $pd before: $($before.Count), $($before.Sum) bytes"
    Rename-Item $pd 'Duplicati.before-7804'
    $moved = $true
    L "renamed $pd -> $bk"
    Say "元のフォルダーを一時的に退避しました: $bk"
} else { L "$pd did not exist, nothing to move" }

try {
    & (Join-Path $here 'repro-7804.ps1') -SkipCleanup
    L 'repro-7804.ps1 finished'
} catch {
    L "repro-7804.ps1 stopped with an error: $($_.Exception.Message)"
    Say "再現のスクリプトがエラーで止まりました: $($_.Exception.Message)" 'Red'
    Say 'このあと片付けと元のフォルダーの復元を行います。' 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Write-Host ''
    Say '----- 後片付け: アンインストールして、元のフォルダーを戻します（画面は出ません、1〜2 分かかります）'
    & (Join-Path $here 'cleanup-7804.ps1') | ForEach-Object { L "  $_" }
    Get-Process | Where-Object { $_.Name -match 'Duplicati' } | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path $pd) {
        Move-Item $pd $kept
        L "moved the test's $pd -> $kept"
    }
    if ($moved) {
        Rename-Item $bk 'Duplicati'
        $after = (Get-ChildItem $pd -Recurse -File -Force | Measure-Object Length -Sum)
        L "renamed $bk back -> $pd; files: $($after.Count), $($after.Sum) bytes (before: $($before.Count), $($before.Sum))"
        if ($after.Count -eq $before.Count -and $after.Sum -eq $before.Sum) { Say "元のフォルダーを戻しました（ファイル数・合計サイズとも元と同じ）: $pd" }
        else { Say "元のフォルダーを戻しましたが、ファイル数か合計サイズが元と違います。run3.txt を見てください: $pd" 'Red' }
    }
    L ("check: $pd exists=" + (Test-Path $pd) + ", $bk exists=" + (Test-Path $bk))
    L 'run3 done.'
    Say '全部終わりました。'
}
