#!/bin/bash
# Builds an MSI with wixl the way ReleaseBuilder does on Linux (Command.CreatePackage.cs),
# from the same harvested folder and file list that the Windows run used.
#   $1 = TrayIcon or Agent
#   $2 = Windows path (as /mnt/c/...) of the harvested folder copy (tmp-msi of the Windows run)
#   $3 = the binfiles.wxs the Windows run wrote (WiX 4 namespace)
#   $4 = output name
# Sources come from ~/dup-msi1 (the branch, extracted from the tracked files).
set -e
SRC=${SRC:-/home/jam/dup-msi1/ReleaseBuilder/Resources/Windows}
OUT=/mnt/c/Users/Jam/AppData/Local/Temp/claude/8062b0f02d09eafd/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/rb
W=/home/jam/wixl-rb-$4
mkdir -p "$W"
cp -r "$SRC/$1" "$SRC/WixUIExtension" "$W/"
mkdir -p "$W/harvest"
cp -r "$2/." "$W/harvest/"
# What PackageSupport.InstallPackageIdentifier adds to the copy before harvesting
printf '%s' "$5" > "$W/harvest/package_type_id.txt"
R="$W/$1"
# ReleaseBuilder writes the same list in the WiX 3 namespace for wixl; only the namespace differs
sed 's|http://wixtoolset.org/schemas/v4/wxs|http://schemas.microsoft.com/wix/2006/wi|' "$3" | sed 's|\\|/|g' > "$R/binfiles.wxs"
# (the list was written on Windows, so the folder separator is a backslash; Linux writes a slash)
# master wrote the child elements without a namespace (xmlns=""); OLD_BINFILES=1 reproduces that
[ -n "$OLD_BINFILES" ] && sed -i "s|<Fragment>|<Fragment xmlns=\"\">|g" "$R/binfiles.wxs"
FRAG="binfiles.wxs"
for f in InstallOptionsDlg.wxs ExitDialog.wxs Shortcuts.wxs Duplicati.wxs; do
    [ -f "$R/$f" ] && FRAG="$FRAG $R/$f"
done
cd "$W"
wixl --ext ui --extdir "$W/WixUIExtension" --define "HarvestPath=$W/harvest/" --arch x64 --output "$W/$4.msi" \
    "$R/binfiles.wxs" ${FRAG#binfiles.wxs}
for sql in "$R"/*.sql; do
    grep -v '^\s*--' "$sql" | tr -d '\r' | sed 's/^\s*//; s/\s*$//' | grep -v '^$' | while IFS= read -r q; do
        msibuild "$W/$4.msi" -q "$q"
    done
done
cp "$W/$4.msi" "$OUT/$4.msi"
echo "Built $OUT/$4.msi"
