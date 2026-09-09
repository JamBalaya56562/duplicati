<#
  duplicati/duplicati#3264 の確認: Volume GUID（\\?\Volume{GUID}\）で指定したソースで、ドライブ文字が変わったときの動き。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\test-volume-guid-3264.ps1

  全自動（画面も質問も出ない）。このフォルダーの中に 64 MB の仮想ディスク（VHDX）を作って付け、次の順に試す:
    1. 空いているドライブ文字 A に付けてバックアップ
    2. ドライブ文字を B に変え、ファイルを 1 つ書き換えてバックアップ
    3. 2 回のバックアップの違い（compare）と、最新のバックアップに入っているパス（find）を記録し、復元して中身を比べる
    4. ドライブ文字を外してフォルダー（このフォルダーの mnt）にだけ付けてバックアップ
    5. 仮想ディスクを外してバックアップ
  Duplicati はインストールせず、リポジトリでビルドした CLI を使う。バックアップ先もデータベースもこのフォルダーの中。
  最後に仮想ディスクを必ず外して消す。結果は .\result.txt
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cli  = 'C:\Users\Jam\Documents\duplicati\Executables\Duplicati.CommandLine\bin\Debug\net10.0\Duplicati.CommandLine.exe'
$work = Join-Path $here 'work'
$vhd  = Join-Path $work 'test-3264.vhdx'
$mnt  = Join-Path $work 'mnt'
$dest = Join-Path $work 'dest'
$db   = Join-Path $work 'backup.sqlite'
$rest = Join-Path $work 'restore'
$out  = Join-Path $here 'result.txt'

function W([string]$t) { $t | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function DiskPart([string[]]$lines) {
    $f = Join-Path $work 'diskpart.txt'
    $lines | Set-Content -Path $f -Encoding ascii
    $r = & diskpart.exe /s $f 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "diskpart failed ($LASTEXITCODE): $r" }
}
# Runs the CLI and writes the lines that matter (summary, warnings, errors) to the result
function Invoke-DupCli([string]$label, [string[]]$cliArgs) {
    W ''; W "----- $label"
    W ("  > Duplicati.CommandLine " + ($cliArgs -join ' '))
    $r = & $cli @cliArgs 2>&1 | Out-String
    W "  exit code: $LASTEXITCODE"
    foreach ($l in ($r -split "`r?`n" | Where-Object { $_.Trim() })) { W "  | $l" }
}
function Backup([string]$label, [string]$source) {
    Invoke-DupCli $label @('backup', "file://$dest", $source, "--dbpath=$db", '--no-encryption=true', '--snapshot-policy=off', '--console-log-level=Information', '--disable-module=console-password-input')
}
function FreeLetters {
    $used = (Get-PSDrive -PSProvider FileSystem).Name + (Get-Volume | Where-Object DriveLetter | ForEach-Object { [string]$_.DriveLetter })
    'R', 'S', 'T', 'U', 'V', 'W' | Where-Object { $used -notcontains $_ }
}

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
if (-not (Test-Path $cli)) { throw "何も変えずに止めました: CLI がありません: $cli" }
if (Test-Path $work) { throw "何も変えずに止めました: $work がすでにあります（前回の残り）。" }
$free = @(FreeLetters)
if ($free.Count -lt 2) { throw '何も変えずに止めました: R〜W に空いているドライブ文字が 2 つありません。' }
$a = $free[0]; $b = $free[1]

if (Test-Path $out) { Remove-Item $out }
New-Item -ItemType Directory -Force $work, $mnt, $dest, $rest | Out-Null
W "test started $(Get-Date -Format s); drive letters $a then $b; cli $((Get-Item $cli).LastWriteTime.ToString('s'))"
$attached = $false
try {
    Say "仮想ディスクを作って ${a}: に付けます..."
    DiskPart @("create vdisk file=`"$vhd`" maximum=64 type=expandable", "select vdisk file=`"$vhd`"", 'attach vdisk', 'create partition primary', 'format fs=ntfs quick label=DUP3264', "assign letter=$a")
    $attached = $true
    Start-Sleep 3
    $guid = (Get-Volume -DriveLetter $a).UniqueId
    W "volume: $guid on ${a}:"
    New-Item -ItemType Directory -Force "${a}:\data\sub" | Out-Null
    'first file' | Set-Content "${a}:\data\a.txt"
    'second file, version 1' | Set-Content "${a}:\data\b.txt"
    $bytes = [byte[]]::new(1MB); [Random]::new(3264).NextBytes($bytes); [IO.File]::WriteAllBytes("${a}:\data\sub\c.bin", $bytes)
    $src = $guid + 'data\'

    Say "1. ${a}: でバックアップします..."
    Backup "1. backup with the volume on ${a}:" $src

    Say "2. ドライブ文字を ${b}: に変えて、ファイルを 1 つ書き換えてバックアップします..."
    Get-Partition -DriveLetter $a | Set-Partition -NewDriveLetter $b
    Start-Sleep 3
    W ''; W "drive letter changed: $((Get-Volume | Where-Object UniqueId -eq $guid).DriveLetter):"
    'second file, version 2' | Set-Content "${b}:\data\b.txt"
    Backup "2. backup with the volume on ${b}: (b.txt changed)" $src

    Say '3. 2 回のバックアップの違いと中身を記録して、復元します...'
    Invoke-DupCli '3a. compare version 1 (older) with version 0 (newer)' @('compare', "file://$dest", '1', '0', "--dbpath=$db", '--no-encryption=true', '--full-result=true')
    Invoke-DupCli '3b. files in version 0' @('find', "file://$dest", '*', '--version=0', "--dbpath=$db", '--no-encryption=true')
    Invoke-DupCli '3c. files in version 1' @('find', "file://$dest", '*', '--version=1', "--dbpath=$db", '--no-encryption=true')
    Invoke-DupCli '3d. restore version 0' @('restore', "file://$dest", '*', '--version=0', "--restore-path=$rest", "--dbpath=$db", '--no-encryption=true')
    $orig = Get-ChildItem "${b}:\data" -Recurse -File | ForEach-Object { "$([IO.Path]::GetRelativePath("${b}:\data", $_.FullName)) $((Get-FileHash $_.FullName).Hash)" } | Sort-Object
    $back = Get-ChildItem $rest -Recurse -File | ForEach-Object { "$([IO.Path]::GetRelativePath($rest, $_.FullName)) $((Get-FileHash $_.FullName).Hash)" } | Sort-Object
    W ''; W '----- 3e. restored files compared with the volume (relative path and SHA-256)'
    W ("  volume  : " + ($orig -join ' | '))
    W ("  restored: " + ($back -join ' | '))

    Say '4. ドライブ文字を外してフォルダーにだけ付けてバックアップします...'
    $part = Get-Partition -DriveLetter $b
    $part | Add-PartitionAccessPath -AccessPath ($mnt + '\')
    $part | Remove-PartitionAccessPath -AccessPath "${b}:\"
    Start-Sleep 3
    W ''; W "access paths now: $(((Get-Partition | Where-Object { $_.AccessPaths -contains $guid }).AccessPaths) -join ', ')"
    Backup '4. backup with the volume mounted only on a folder' $src

    Say '5. 仮想ディスクを外してバックアップします...'
    Get-Partition | Where-Object { $_.AccessPaths -contains $guid } | Remove-PartitionAccessPath -AccessPath ($mnt + '\')
    DiskPart @("select vdisk file=`"$vhd`"", 'detach vdisk'); $attached = $false
    Backup '5. backup with the volume detached' $src
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say '後片付け: 仮想ディスクを外して消します...'
    if ($attached) { try { DiskPart @("select vdisk file=`"$vhd`"", 'detach vdisk') } catch { W "detach failed: $($_.Exception.Message)" } }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    W ''; W "cleanup: work folder present=$(Test-Path $work); letters $a/$b in use=$(@((Get-PSDrive -PSProvider FileSystem).Name | Where-Object { $_ -in $a, $b }).Count -gt 0)"
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。'
}
