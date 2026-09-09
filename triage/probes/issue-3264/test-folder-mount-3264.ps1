<#
  duplicati/duplicati#3264 の修正（fix/volume-guid-folder-mount）の確認: フォルダーにだけ付けたボリュームを \\?\Volume{GUID}\ で指定する。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\test-folder-mount-3264.ps1

  全自動（画面も質問も出ない）。このフォルダーの中に 64 MB の仮想ディスク（VHDX）を作り、次の順に試す:
    1. フォルダー（このフォルダーの work\mnt）にだけ付けてバックアップし、入ったパスを記録、復元して中身を比べる
    2. ドライブ文字にも付けてバックアップ（ドライブ文字が優先されるか）
    3. どこにも付けずにバックアップ（見つからないエラーになるか）
  Duplicati はインストールせず、リポジトリでビルドした CLI を使う。最後に仮想ディスクを必ず外して消す。結果は .\result-folder.txt
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
$out  = Join-Path $here 'result-folder.txt'

function W([string]$t) { $t | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function Invoke-DiskPartScript([string[]]$lines) {
    $f = Join-Path $work 'diskpart.txt'
    $lines | Set-Content -Path $f -Encoding ascii
    $r = & diskpart.exe /s $f 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "diskpart failed ($LASTEXITCODE): $r" }
}
# Runs the CLI and writes the lines that matter to the result (backend chatter left out)
function Invoke-DupCli([string]$label, [string[]]$cliArgs) {
    W ''; W "----- $label"
    W ("  > Duplicati.CommandLine " + ($cliArgs -join ' '))
    $r = & $cli @cliArgs 2>&1 | Out-String
    W "  exit code: $LASTEXITCODE"
    foreach ($l in ($r -split "`r?`n" | Where-Object { $_.Trim() -and $_ -notmatch 'Backend event|Uploading file|Downloading file|Listing remote' })) { W "  | $l" }
}
function Invoke-DupBackup([string]$label, [string]$source) {
    Invoke-DupCli $label @('backup', "file://$dest", $source, "--dbpath=$db", '--no-encryption=true', '--snapshot-policy=off', '--console-log-level=Information', '--disable-module=console-password-input')
}
function Get-AccessPaths([string]$guid) { ((Get-Partition | Where-Object { $_.AccessPaths -contains $guid }).AccessPaths) -join ', ' }

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
if (-not (Test-Path $cli)) { throw "何も変えずに止めました: CLI がありません: $cli" }
if (Test-Path $work) { throw "何も変えずに止めました: $work がすでにあります（前回の残り）。" }
$used = (Get-PSDrive -PSProvider FileSystem).Name + (Get-Volume | Where-Object DriveLetter | ForEach-Object { [string]$_.DriveLetter })
$letter = 'R', 'S', 'T', 'U', 'V', 'W' | Where-Object { $used -notcontains $_ } | Select-Object -First 1
if (-not $letter) { throw '何も変えずに止めました: R〜W に空いているドライブ文字がありません。' }

if (Test-Path $out) { Remove-Item $out }
New-Item -ItemType Directory -Force $work, $mnt, $dest, $rest | Out-Null
W "test started $(Get-Date -Format s); cli $((Get-Item $cli).LastWriteTime.ToString('s')); free letter $letter"
$attached = $false
try {
    Say '仮想ディスクを作って、フォルダーにだけ付けます...'
    Invoke-DiskPartScript @("create vdisk file=`"$vhd`" maximum=64 type=expandable", "select vdisk file=`"$vhd`"", 'attach vdisk', 'create partition primary', 'format fs=ntfs quick label=DUP3264', "assign mount=`"$mnt`"")
    $attached = $true
    Start-Sleep 3
    $guid = (Get-Partition | Where-Object { $_.AccessPaths -contains ($mnt + '\') }).AccessPaths | Where-Object { $_ -like '\\?\Volume*' } | Select-Object -First 1
    W "volume: $guid; access paths: $(Get-AccessPaths $guid)"
    W ("Win32_Volume: " + ((Get-CimInstance Win32_Volume | Where-Object DeviceID -eq $guid | ForEach-Object { "DriveLetter=[$($_.DriveLetter)] Name=[$($_.Name)]" }) -join '; '))
    New-Item -ItemType Directory -Force "$mnt\data\sub" | Out-Null
    'first file' | Set-Content "$mnt\data\a.txt"
    $bytes = [byte[]]::new(1MB); [Random]::new(3264).NextBytes($bytes); [IO.File]::WriteAllBytes("$mnt\data\sub\c.bin", $bytes)
    $src = $guid + 'data\'

    Say '1. フォルダーにだけ付けた状態でバックアップして、復元します...'
    Invoke-DupBackup '1. backup with the volume mounted only on a folder' $src
    Invoke-DupCli '1b. files in version 0' @('find', "file://$dest", '*', '--version=0', "--dbpath=$db", '--no-encryption=true')
    Invoke-DupCli '1c. restore version 0' @('restore', "file://$dest", '*', '--version=0', "--restore-path=$rest", "--dbpath=$db", '--no-encryption=true')
    $orig = Get-ChildItem "$mnt\data" -Recurse -File | ForEach-Object { "$([IO.Path]::GetRelativePath("$mnt\data", $_.FullName)) $((Get-FileHash $_.FullName).Hash)" } | Sort-Object
    $back = Get-ChildItem $rest -Recurse -File | ForEach-Object { "$([IO.Path]::GetRelativePath($rest, $_.FullName)) $((Get-FileHash $_.FullName).Hash)" } | Sort-Object
    W ''; W '----- 1d. restored files compared with the volume (relative path and SHA-256)'
    W ("  volume  : " + ($orig -join ' | '))
    W ("  restored: " + ($back -join ' | '))
    W ("  same: " + (($orig -join '|') -eq ($back -join '|')))

    Say "2. ドライブ文字 ${letter}: にも付けてバックアップします..."
    Get-Partition | Where-Object { $_.AccessPaths -contains $guid } | Add-PartitionAccessPath -AccessPath "${letter}:\"
    Start-Sleep 3
    W ''; W "access paths now: $(Get-AccessPaths $guid)"
    Invoke-DupBackup "2. backup with the volume on ${letter}: and the folder" $src
    Invoke-DupCli '2b. files in version 0' @('find', "file://$dest", '*', '--version=0', "--dbpath=$db", '--no-encryption=true')

    Say '3. どこにも付けずにバックアップします...'
    $part = Get-Partition | Where-Object { $_.AccessPaths -contains $guid }
    $part | Remove-PartitionAccessPath -AccessPath "${letter}:\"
    $part | Remove-PartitionAccessPath -AccessPath ($mnt + '\')
    Start-Sleep 3
    W ''; W "access paths now: $(Get-AccessPaths $guid)"
    W ("Win32_Volume: " + ((Get-CimInstance Win32_Volume | Where-Object DeviceID -eq $guid | ForEach-Object { "DriveLetter=[$($_.DriveLetter)] Name=[$($_.Name)]" }) -join '; '))
    Invoke-DupBackup '3. backup with the volume not mounted anywhere' $src
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say '後片付け: 仮想ディスクを外して消します...'
    if ($attached) { try { Invoke-DiskPartScript @("select vdisk file=`"$vhd`"", 'detach vdisk') } catch { W "detach failed: $($_.Exception.Message)" } }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    W ''; W "cleanup: work folder present=$(Test-Path $work); letter $letter in use=$([bool](Get-PSDrive -PSProvider FileSystem | Where-Object Name -eq $letter))"
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。'
}
