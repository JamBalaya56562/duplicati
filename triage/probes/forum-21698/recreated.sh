#!/bin/bash
# forum 21698 on the current version, the case of the forum topic: the database is recreated while the
# 7z volumes are on the destination, so the database has no record of them. Then backup and repair.
# As in renamed.sh, the 7z volume is a renamed zip dlist (the old versions cannot write 7z on Linux).
CLI="$*"
O="--passphrase=test1234 --console-log-level=Warning"
mkdir -p /work/src /work/dst
for i in $(seq 1 20); do head -c 50000 /dev/urandom > /work/src/f$i; done
$CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite $O > /dev/null 2>&1; echo "backup 1: exit $?"
sleep 2
for i in $(seq 1 5); do head -c 50000 /dev/urandom > /work/src/f$i; done
$CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite $O > /dev/null 2>&1; echo "backup 2: exit $?"
first=$(ls /work/dst | grep dlist | sort | head -1)
seven="${first/.zip.aes/.7z.aes}"
mv "/work/dst/$first" "/work/dst/$seven"
echo "renamed $first -> $seven"
rm -f /work/db.sqlite
show() { grep -iE "error|warn|fail|missing|7z|module|exception|delet|extra" | grep -v "^ *at " | cut -c1-260 | head -8; }
present() { echo "  $seven on the destination: $([ -f "/work/dst/$seven" ] && echo yes || echo NO)"; }

echo "--- repair without a database (recreate)"; $CLI repair file:///work/dst --dbpath=/work/db.sqlite $O 2>&1 | show; echo "exit ${PIPESTATUS[0]}"; present
echo "  versions in the recreated database: $($CLI list file:///work/dst --dbpath=/work/db.sqlite $O 2>/dev/null | grep -c '^[0-9]')"
for i in $(seq 6 8); do head -c 50000 /dev/urandom > /work/src/f$i; done
cp /work/db.sqlite /work/db-recreated.sqlite
echo "--- backup"; $CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite $O 2>&1 | show; echo "exit ${PIPESTATUS[0]}"; present
echo "--- repair"; $CLI repair file:///work/dst --dbpath=/work/db.sqlite $O 2>&1 | show; echo "exit ${PIPESTATUS[0]}"; present
echo "--- versions now: $($CLI list file:///work/dst --no-local-db=true $O 2>/dev/null | grep -c '^[0-9]')"
