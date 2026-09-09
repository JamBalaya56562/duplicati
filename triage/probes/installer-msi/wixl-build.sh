#!/bin/bash
# Builds the TrayIcon MSI the way ReleaseBuilder does on Linux (Command.CreatePackage.cs):
# wixl --ext ui --extdir WixUIExtension --define HarvestPath=... --arch x64, then the *.sql
# files of the resource folder applied with msibuild. $1 = name of the exported source folder.
set -e
S=/mnt/c/Users/Jam/AppData/Local/Temp/claude/8062b0f02d09eafd/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/msi
W=/home/jam/wixl-$1
rm -rf "$W" && mkdir -p "$W"
cp -r "$S/wixl-$1/." "$W/"
mkdir -p "$W/harvest"
cp "$S/harvest/"*.exe "$W/harvest/"
R="$W/TrayIcon"
# The harvested file list, in the WiX 3 namespace that wixl reads
cat > "$R/binfiles.wxs" <<'EOF'
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Fragment>
    <DirectoryRef Id="INSTALLLOCATION">
      <Component Id="Duplicati.GUI.TrayIcon.exe" Guid="*">
        <File Id="Duplicati.GUI.TrayIcon.exe" KeyPath="yes" DefaultVersion="2.0.0.99" Source="$(var.HarvestPath)Duplicati.GUI.TrayIcon.exe" />
      </Component>
    </DirectoryRef>
  </Fragment>
  <Fragment>
    <ComponentGroup Id="DUPLICATIBIN">
      <ComponentRef Id="Duplicati.GUI.TrayIcon.exe" />
    </ComponentGroup>
  </Fragment>
</Wix>
EOF
cd "$R"
wixl --ext ui --extdir "$W/WixUIExtension" --define "HarvestPath=$W/harvest/" --arch x64 --output "$W/$1.msi" \
    binfiles.wxs InstallOptionsDlg.wxs ExitDialog.wxs Shortcuts.wxs Duplicati.wxs
for sql in "$R"/*.sql; do
    grep -v '^\s*--' "$sql" | sed 's/^\s*//; s/\s*$//' | grep -v '^$' | while IFS= read -r q; do
        msibuild "$W/$1.msi" -q "$q"
    done
done
cp "$W/$1.msi" "$S/wixl-$1.msi"
echo "Built $S/wixl-$1.msi"
