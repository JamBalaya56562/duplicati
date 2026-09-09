<#
  管理者の権限が要るので手元で流れていなかった USN ジャーナルと DiskImage のテストを、管理者で流す。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\test-usn-diskimage.ps1

  全自動（質問は出ない）。master のビルド済みのテスト（Duplicati.UnitTest.dll）をそのまま使い、ビルドはしない:
    - Category が USN のテスト（Issue4951 の RenameCaseChangeUSNAsync、UsnJournalPurgedLogTests、UsnSourceFileBackupTests）
    - DiskImage の Test_RawDisk_DisposeWhileReading_DoesNotCrash_Async（#7759、テストが 100 MB の VHDX を 2 つ作って付ける）
  終わったら、テストが外し忘れた VHDX が残っていないか確かめて、残っていれば外す。結果は .\result.txt
#>
$ErrorActionPreference = 'Stop'
# dotnet test writes UTF-8; without this the Japanese in its output is decoded as the OEM code page
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$dotnet = 'C:\Users\Jam\AppData\Local\mise\dotnet-root\dotnet.exe'
$dll    = 'C:\Users\Jam\Documents\duplicati\Duplicati\UnitTest\bin\Debug\net10.0\Duplicati.UnitTest.dll'
$filter = 'TestCategory=USN|FullyQualifiedName~Test_RawDisk_DisposeWhileReading_DoesNotCrash_Async'
$out    = Join-Path $here 'result.txt'
$log    = Join-Path $here 'test-output.txt'

function W([string]$t) { $t | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function Get-LeftoverDisks { Get-Disk | Where-Object { $_.Location -like '*duplicati_*_class_test*' } }

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
foreach ($f in $dotnet, $dll) { if (-not (Test-Path $f)) { throw "何も変えずに止めました: 見つかりません: $f" } }
if (Get-LeftoverDisks) { throw '何も変えずに止めました: 前回のテストの VHDX が付いたままです。' }

foreach ($f in $out, $log) { if (Test-Path $f) { Remove-Item $f } }
W "test started $(Get-Date -Format s); dll $((Get-Item $dll).LastWriteTime.ToString('s'))"
W "filter: $filter"
try {
    Say 'テストを流しています（数分かかります）...'
    & $dotnet test $dll --filter $filter --logger 'console;verbosity=normal' 2>&1 | Tee-Object -FilePath $log | Out-Null
    W "exit code: $LASTEXITCODE"
    W ''; W '----- results'
    foreach ($l in (Get-Content $log | Where-Object { $_ -match '^\s+(成功|失敗|スキップ|Passed|Failed|Skipped) |テストの合計数|成功:|失敗:|スキップ:|合計時間|Total tests|Passed:|Failed:|Skipped:' })) { W "  $l" }
    W ''; W '----- error messages'
    $lines = Get-Content $log
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'エラー メッセージ|Error Message|Assert\.Ignore|スキップ理由|^\s+(Reading the USN|The USN journal|DiskImage tests require)') {
            $lines[[Math]::Max(0, $i - 1)..[Math]::Min($lines.Count - 1, $i + 3)] | ForEach-Object { W "  | $_" }
        }
    }
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say '後片付け: テストの VHDX が残っていないか確かめます...'
    $left = @(Get-LeftoverDisks)
    W ''; W "leftover test disks: $($left.Count)"
    foreach ($d in $left) {
        W "  detaching $($d.Location)"
        try { Dismount-DiskImage -ImagePath $d.Location | Out-Null } catch { W "  detach failed: $($_.Exception.Message)" }
    }
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。結果は result.txt です。'
}
