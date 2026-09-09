# Applies the queries the way BuildMsiPackage does (one msibuild -q per query) to a copy of a wixl MSI
set -e
cp "$1" "$3"
while IFS= read -r q; do q="${q%$'\r'}"; [ -n "$q" ] && msibuild "$3" -q "$q"; done < "$2"
msiinfo export "$3" Property | grep -a SecureCustom
