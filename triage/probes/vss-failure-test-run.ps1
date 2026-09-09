# Run in an ELEVATED PowerShell (Run as administrator).
# Runs WindowsSnapshotFailureTests.ASnapshotAfterAFailedSnapshotWorks for each build and
# provider, each in its own process, 30 s apart, and writes a log next to this script.
#   bin-branch: master with #7419 + the Vanara change (fix/vss-failed-snapshot-releases-set)
#   bin-master: master with #7419 + the test only
# The run expected to fail (master, Vanara) is last, as a failed run can leave a snapshot set
# in progress for a few minutes.
$ErrorActionPreference = 'Continue'
$env:DOTNET_CLI_UI_LANGUAGE = 'en'
$dotnet = 'C:\Users\Jam\AppData\Local\mise\dotnet-root\dotnet.exe'
$s = $PSScriptRoot
$log = Join-Path $s 'vss-failure-test.log'
$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
"start $(Get-Date -Format o) elevated=$elevated" | Set-Content -Encoding utf8 $log
if (-not $elevated) { 'NOT ELEVATED - run this from an elevated PowerShell' | Add-Content -Encoding utf8 $log; Get-Content $log; return }

$runs = @(
    @('branch', 'Native'),
    @('branch', 'Vanara'),
    @('master', 'Native'),
    @('master', 'Vanara')
)
foreach ($r in $runs) {
    $name = "$($r[0])-$($r[1])"
    "===== $name $(Get-Date -Format o)" | Add-Content -Encoding utf8 $log
    & $dotnet test (Join-Path $s "bin-$($r[0])\Duplicati.UnitTest.dll") `
        --filter "FullyQualifiedName~WindowsSnapshotFailureTests&Name~$($r[1])" `
        --logger "console;verbosity=normal" --logger "trx;LogFileName=$name.trx" --results-directory (Join-Path $s 'results') 2>&1 |
        Where-Object { $_ -match 'Passed|Failed|Skipped|Total|Error Message|Exception|snapshot|Assert' } |
        Add-Content -Encoding utf8 $log
    Start-Sleep -Seconds 30
}
"end $(Get-Date -Format o)" | Add-Content -Encoding utf8 $log
Get-Content $log
