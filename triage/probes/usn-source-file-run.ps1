# Run in an ELEVATED PowerShell (Run as administrator).
$ErrorActionPreference = 'Continue'
$s = 'C:\Users\Jam\AppData\Local\Temp\claude\C--Users-Jam-Documents-duplicati\d37b421e-cf8d-4dd1-aead-0bfcff9f7dc8\scratchpad\usn'
$log = "$s\usn-run-2.log"
"start $(Get-Date -Format o) elevated=$(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" | Set-Content -Encoding utf8 $log
$runs = @(
  @('green', 'UsnSourceFileBackupTests'),
  @('green', 'Issue4951'),
  @('green', 'UsnSourceFileFilterTests'),
  @('red', 'UsnSourceFileBackupTests')
)
foreach ($r in $runs) {
    "===== $($r[0]) $($r[1])" | Add-Content -Encoding utf8 $log
    & 'C:\Users\Jam\AppData\Local\mise\dotnet-root\dotnet.exe' test "$s\bin-$($r[0])\Duplicati.UnitTest.dll" --filter "FullyQualifiedName~$($r[1])" --logger "console;verbosity=normal" --logger "trx;LogFileName=$s\trx-$($r[0])-$($r[1]).trx" 2>&1 | Add-Content -Encoding utf8 $log
}
"end $(Get-Date -Format o)" | Add-Content -Encoding utf8 $log
