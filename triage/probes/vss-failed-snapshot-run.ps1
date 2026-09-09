# Run in an ELEVATED PowerShell (Run as administrator). Each run is its own process.
$ErrorActionPreference = 'Continue'
$s = 'C:\Users\Jam\AppData\Local\Temp\claude\C--Users-Jam-Documents-duplicati\d37b421e-cf8d-4dd1-aead-0bfcff9f7dc8\scratchpad\vss'
$log = "$s\vss-probe-2.log"
"start $(Get-Date -Format o) elevated=$(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" | Set-Content -Encoding utf8 $log
$runs = @(
  @('B2', 'TwoSnapshotsInARowWork', 'Native'),
  @('B2', 'ASnapshotAfterAFailedOneWorks', 'Native'),
  @('B2', 'ASnapshotAfterAFailedOneWorks', 'Vanara'),
  @('B2', 'ASnapshotAfterAFailedOneWorks', 'AlphaVSS'),
  @('B1', 'ASnapshotAfterAFailedOneWorks', 'Native'),
  @('B1', 'ASnapshotAfterAFailedOneWorks', 'AlphaVSS'),
  @('B1', 'ASnapshotAfterAFailedOneWorks', 'Vanara')
)
foreach ($r in $runs) {
    "===== $($r[0]) $($r[1]) $($r[2])" | Add-Content -Encoding utf8 $log
    & 'C:\Users\Jam\AppData\Local\mise\dotnet-root\dotnet.exe' test "$s\bin-$($r[0])\Duplicati.UnitTest.dll" --filter "FullyQualifiedName~VssFailedSnapshotProbe.$($r[1])&Name~$($r[2])" --logger "console;verbosity=normal" 2>&1 |
        Where-Object { $_ -match 'PROBEVSS|inner:|passed|failed|skipped|Passed|Failed|Skipped|成功|失敗|スキップ|合計' } | Add-Content -Encoding utf8 $log
    Start-Sleep -Seconds 30
}
"end $(Get-Date -Format o)" | Add-Content -Encoding utf8 $log
Get-Content $log
