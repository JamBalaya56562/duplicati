# Run in a NORMAL (not elevated) PowerShell, after wix-install-check.ps1.
# Checks whether properties set in the installer UI reach the elevated part of the installation
# (fix/msi-wixl-secure-properties). Each MSI opens its normal UI:
#   1. click through with the defaults (Next, accept the license, Next, Install)
#   2. accept the UAC prompt when it appears
#   3. click Finish
# The script then counts "Ignoring disallowed property" in the log and uninstalls (another UAC prompt).
#   master : wixl build of master (SecureCustomProperties = PREVIOUSVERSIONSINSTALLED only)
#   fixed  : the same MSI with the SecureCustomProperties list written by the branch
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$out = Join-Path $dir 'secure-check-result.txt'
$result = [System.Collections.Generic.List[string]]::new()
function Say($s) { $result.Add($s); $s }

$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Say "user: $env:USERDOMAIN\$env:USERNAME, elevated: $elevated"
if ($elevated) {
    Say 'STOP: run this from a normal PowerShell; an elevated one passes every property.'
    $result | Set-Content -Path $out -Encoding utf8
    return
}
if (Test-Path 'C:\Program Files\Duplicati 2') {
    Say 'STOP: C:\Program Files\Duplicati 2 exists; nothing was changed.'
    $result | Set-Content -Path $out -Encoding utf8
    return
}

foreach ($run in @(@('master', 'wixlmaster-gui.msi'), @('fixed', 'wixlsec-gui.msi'))) {
    $name, $file = $run
    $msi = Join-Path $dir $file
    $log = Join-Path $dir "secure-$name-install.log"
    Say "=== $name ($file): follow the installer window, accept UAC"
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" NOSCRIPT=true /l*v `"$log`"" -Wait -PassThru
    Say "  msiexec exit code: $($p.ExitCode)"
    $lines = @(Select-String -Path $log -Pattern 'Ignoring disallowed property (\S+)' -Encoding unicode)
    Say "  'Ignoring disallowed property' lines: $($lines.Count)$(if ($lines) { ' -> ' + (($lines | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique) -join ', ') })"
    $restricted = @(Select-String -Path $log -Pattern 'RestrictedUserControl' -Encoding unicode | Select-Object -First 1)
    Say "  RestrictedUserControl in log: $($restricted.Count -gt 0)"
    $p = Start-Process msiexec.exe -ArgumentList "/x `"$msi`" /qb NOSCRIPT=true /l*v `"$(Join-Path $dir "secure-$name-uninstall.log")`"" -Wait -PassThru
    Say "  uninstall exit code: $($p.ExitCode); install folder left: $(Test-Path 'C:\Program Files\Duplicati 2')"
}

$result | Set-Content -Path $out -Encoding utf8
"Written to $out"
