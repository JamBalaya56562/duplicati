# Run in an elevated (administrator) PowerShell.
# Detaches the test VHDX created by mount-vhd.ps1 and removes C:\ofs-test.
$ErrorActionPreference = 'Stop'
$root    = 'C:\ofs-test'
$vhd     = Join-Path $root 'ofs-test.vhdx'
$mounted = Join-Path $root 'src\mounted'

if (Test-Path $mounted) { mountvol "$mounted\" /D }

if (Test-Path $vhd) {
    $script = @"
select vdisk file="$vhd"
detach vdisk
"@
    $tmp = Join-Path $env:TEMP 'ofs-unmount.txt'
    Set-Content -Path $tmp -Value $script -Encoding ascii
    diskpart /s $tmp
    Remove-Item $tmp
}

Remove-Item $root -Recurse -Force
"Removed $root"
