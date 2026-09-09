param(
    [Parameter(Mandatory)] [string] $Revision,   # jj revision whose installer sources are used
    [Parameter(Mandatory)] [string] $OutName,
    [string] $ProductVersion                      # overrides the version in UpgradeData.wxi, for upgrade tests
)
$ErrorActionPreference = 'Stop'
$scratch = Split-Path -Parent $PSCommandPath
$repo    = 'C:\Users\Jam\Documents\duplicati'
$wix     = Join-Path (Split-Path -Parent $scratch) 'wixtool\wix.exe'
$jj      = (Get-ChildItem "$env:USERPROFILE\AppData\Local\mise\installs\jj\*\jj.exe" | Select-Object -Last 1).FullName
$work    = Join-Path $scratch "work-$OutName"
$harvest = Join-Path $scratch 'harvest\'

if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory $work | Out-Null

# The installer sources at the given revision, written byte for byte
$sub = 'ReleaseBuilder/Resources/Windows/TrayIcon'
$files = & $jj file list -r $Revision $sub
foreach ($f in $files) {
    $rel = $f.Substring($sub.Length + 1) -replace '/', '\'
    $dest = Join-Path $work $rel
    New-Item -ItemType Directory -Force (Split-Path -Parent $dest) | Out-Null
    $p = Start-Process -FilePath $jj -ArgumentList @('file', 'show', '-r', $Revision, $f) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $dest -WorkingDirectory $repo
    if ($p.ExitCode -ne 0) { throw "jj file show failed for $f" }
}

# The release build replaces the WiX 3 namespace with the WiX 4 one before building
$ns3 = 'http://schemas.microsoft.com/wix/2006/wi'
$ns4 = 'http://wixtoolset.org/schemas/v4/wxs'
$fragments = 'InstallOptionsDlg.wxs', 'ExitDialog.wxs', 'Shortcuts.wxs', 'Duplicati.wxs' | ForEach-Object { Join-Path $work $_ }
# Only swapping the namespace does not build (Product is WiX 3 syntax), so convert the files
& $wix convert @fragments (Join-Path $work 'UpgradeData.wxi') | Out-Null

if ($ProductVersion) {
    $wxi = Join-Path $work 'UpgradeData.wxi'
    $text = [regex]::Replace([IO.File]::ReadAllText($wxi), '<\?define ProductVersion="[^"]*" \?>', "<?define ProductVersion=`"$ProductVersion`" ?>")
    [IO.File]::WriteAllText($wxi, $text)
}

# The converter nests the StartupFolder standard directory in ProgramMenuFolder, which WiX 4 rejects
$sc = Join-Path $work 'Shortcuts.wxs'
$text = [IO.File]::ReadAllText($sc)
$text = [regex]::Replace($text, '<StandardDirectory Id="ProgramMenuFolder">\s*<StandardDirectory Id="StartupFolder">([\s\S]*?)</StandardDirectory>\s*</StandardDirectory>', '<StandardDirectory Id="StartupFolder">$1</StandardDirectory>')
[IO.File]::WriteAllText($sc, $text)

# WiX 4 does not let MsiHiddenProperties be authored; it does not touch the tables compared here
$dw = Join-Path $work 'Duplicati.wxs'
$text = [IO.File]::ReadAllText($dw)
$text = [regex]::Replace($text, '\s*<Property Id="MsiHiddenProperties"[^>]*/>', '')
# The SDDL form is the core MsiLockPermissionsEx element, not the util one
$text = $text.Replace('<util:PermissionEx Sddl=', '<PermissionEx Sddl=')
# WiX 4 does not let a project redefine a WixUI dialog, so the own exit dialog gets its own name
$text = $text.Replace('"ExitDialog"', '"DuplicatiExitDialog"')
[IO.File]::WriteAllText($dw, $text)
$ed = Join-Path $work 'ExitDialog.wxs'
[IO.File]::WriteAllText($ed, [IO.File]::ReadAllText($ed).Replace('"ExitDialog"', '"DuplicatiExitDialog"'))
$text = [IO.File]::ReadAllText($dw)
[IO.File]::WriteAllText($dw, $text)

# A stand-in for the harvested program files: only the TrayIcon executable is referenced by id
$binfiles = Join-Path $work 'binfiles.wxs'
@"
<Wix xmlns="$ns4">
  <Fragment>
    <DirectoryRef Id="INSTALLLOCATION">
      <Component Id="Duplicati.GUI.TrayIcon.exe" Guid="*">
        <File Id="Duplicati.GUI.TrayIcon.exe" KeyPath="yes" DefaultVersion="2.0.0.99" Source="`$(var.HarvestPath)Duplicati.GUI.TrayIcon.exe" />
      </Component>
    </DirectoryRef>
  </Fragment>
  <Fragment>
    <ComponentGroup Id="DUPLICATIBIN">
      <ComponentRef Id="Duplicati.GUI.TrayIcon.exe" />
    </ComponentGroup>
  </Fragment>
</Wix>
"@ | Set-Content -Path $binfiles -Encoding utf8

Push-Location $work
try {
    & $wix extension add WixToolset.UI.wixext/4.0.6 | Out-Null
    & $wix extension add WixToolset.Util.wixext/4.0.6 | Out-Null
    $msi = Join-Path $scratch "$OutName.msi"
    & $wix build -ext WixToolset.UI.wixext -ext WixToolset.Util.wixext -define "HarvestPath=$harvest" -define "BuildEnv=Windows" -arch x64 -out $msi $binfiles @fragments
    if ($LASTEXITCODE -ne 0) { throw "wix build failed with $LASTEXITCODE" }
    "Built $msi"
}
finally { Pop-Location }
