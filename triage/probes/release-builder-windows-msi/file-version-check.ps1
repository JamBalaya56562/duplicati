# Run in an elevated (administrator) PowerShell.
# Checks what the File table versions of the wixl MSI change (branch: real file versions in WixHeatBuilder).
#   wixlpv98-gui.msi: 2.0.0.98, every file has the product version (as master builds on Linux)
#   wixlpv99-gui.msi: 2.0.0.99, a file with a version resource has its own version (the branch)
# Both hold the same files. NOSCRIPT=true keeps the install from starting Duplicati.
#   F: install old, delete two DLLs, repair -> are they put back, how many components are skipped
#   G: the same with the new MSI
#   H: install old, upgrade to new -> is any file missing afterwards (#5233), then repair the new one
# Everything is uninstalled at the end of each case.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$old = Join-Path $dir 'wixlpv98-gui.msi'
$new = Join-Path $dir 'wixlpv99-gui.msi'
$harvest = Join-Path $dir 'build\win-x64-gui'
$out = Join-Path $dir 'file-version-check-result.txt'
$installDir = 'C:\Program Files\Duplicati 2'
$probe = @('Aliyun.OSS.Core.dll', 'coreclr.dll')
$result = [System.Collections.Generic.List[string]]::new()
function Say($s) { $result.Add($s); $s }

$installer = New-Object -ComObject WindowsInstaller.Installer
function Related() { @($installer.GetType().InvokeMember('RelatedProducts', 'GetProperty', $null, $installer, @('{1C94BC5A-2BF2-4273-9D8F-2CB30E780D16}'))) }

Say "user: $env:USERDOMAIN\$env:USERNAME, elevated: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
if ((Related).Count -or (Get-Service Duplicati -ErrorAction SilentlyContinue) -or (Test-Path $installDir)) {
    Say 'STOP: Duplicati is installed on this machine; nothing was changed.'
    $result | Set-Content -Path $out -Encoding utf8
    return
}
$expected = @(Get-ChildItem $harvest -Recurse -File | ForEach-Object { $_.FullName.Substring($harvest.Length + 1) })

function Msi($arguments, $log) {
    $p = Start-Process msiexec.exe -ArgumentList "$arguments NOSCRIPT=true /l*v `"$log`"" -Wait -PassThru
    $disallowed = @(Select-String -Path $log -Pattern 'Disallowing installation of component' -Encoding unicode).Count
    $errors = @(Select-String -Path $log -Pattern 'Return value 3' -Encoding unicode).Count
    Say "  msiexec $($arguments.Split(' ')[0]) exit code: $($p.ExitCode); 'Return value 3': $errors; disallowed components: $disallowed"
}

function Files($label) {
    $missing = @($expected | Where-Object { -not (Test-Path (Join-Path $installDir $_)) })
    $versions = ($probe | ForEach-Object { $f = Join-Path $installDir $_; "$_=$(if (Test-Path $f) { (Get-Item $f).VersionInfo.FileVersion } else { 'MISSING' })" }) -join ', '
    Say "  [$label] products: $((Related) -join ',' ); missing files: $($missing.Count) of $($expected.Count)$(if ($missing) { ' -> ' + (($missing | Select-Object -First 8) -join ', ') }); $versions"
}

function DeleteProbes() {
    foreach ($p in $probe) { Remove-Item (Join-Path $installDir $p) -Force }
    Say "  (deleted $($probe -join ', '))"
}

foreach ($case in @(@('F', $old, 'old 2.0.0.98'), @('G', $new, 'new 2.0.0.99'))) {
    $name, $msi, $text = $case
    Say "=== ${name}: $text, delete two DLLs, repair"
    Msi "/i `"$msi`" /qn" (Join-Path $dir "check-$name-install.log")
    Files 'installed'
    DeleteProbes
    Msi "/fvomus `"$msi`" /qn" (Join-Path $dir "check-$name-repair.log")
    Files 'repaired'
    Msi "/x `"$msi`" /qn" (Join-Path $dir "check-$name-uninstall.log")
    Say "  install folder left: $(Test-Path $installDir)"
}

Say '=== H: install old 2.0.0.98, upgrade to new 2.0.0.99, repair new'
Msi "/i `"$old`" /qn" (Join-Path $dir 'check-H-install-old.log')
Files 'old installed'
Msi "/i `"$new`" /qn" (Join-Path $dir 'check-H-upgrade.log')
Files 'upgraded'
Msi "/fvomus `"$new`" /qn" (Join-Path $dir 'check-H-repair.log')
Files 'repaired'
Msi "/x `"$new`" /qn" (Join-Path $dir 'check-H-uninstall.log')
Say "  install folder left: $(Test-Path $installDir); products: $((Related).Count)"

$result | Set-Content -Path $out -Encoding utf8
"Written to $out"
