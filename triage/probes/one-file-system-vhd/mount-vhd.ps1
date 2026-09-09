# Run in an elevated (administrator) PowerShell.
# Creates a 64 MB VHDX, formats it with NTFS and mounts it at C:\ofs-test\src\mounted,
# so that the --one-file-system test has a volume mounted inside a source folder.
$ErrorActionPreference = 'Stop'
$root    = 'C:\ofs-test'
$vhd     = Join-Path $root 'ofs-test.vhdx'
$mounted = Join-Path $root 'src\mounted'

if (Test-Path $vhd) { throw "$vhd already exists. Run unmount-vhd.ps1 first." }
New-Item -ItemType Directory -Force $mounted | Out-Null

$script = @"
create vdisk file="$vhd" maximum=64 type=expandable
select vdisk file="$vhd"
attach vdisk
create partition primary
format fs=ntfs label=OFSTEST quick
assign mount="$mounted"
"@
$tmp = Join-Path $env:TEMP 'ofs-mount.txt'
Set-Content -Path $tmp -Value $script -Encoding ascii
diskpart /s $tmp
Remove-Item $tmp

# Let the normal (non-elevated) user write test files to both folders
icacls "$root\src" /grant "${env:USERNAME}:(OI)(CI)M" | Out-Null
icacls "$mounted\" /grant "${env:USERNAME}:(OI)(CI)M" | Out-Null

"--- check"
fsutil reparsepoint query $mounted | Select-Object -First 3
mountvol | Select-String -SimpleMatch $mounted
"Done. Source folder: $root\src"
