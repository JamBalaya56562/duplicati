#!/bin/bash
# forum 21698 on the current version: a destination where the oldest dlist is named as a 7z volume,
# as the 25 .dlist.7z.aes files left from the time 7z was used. 7z cannot be written on Linux by the
# old versions (they fail with "The given file is not part of this archive"), and the current version
# decides what to do from the name alone, so one zip dlist is renamed.
CLI="$*"
O="--passphrase=test1234 --console-log-level=Warning"
mkdir -p /work/src /work/dst
for i in $(seq 1 20); do head -c 50000 /dev/urandom > /work/src/f$i; done
$CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite $O > /dev/null 2>&1; echo "backup 1: exit $?"
sleep 2
for i in $(seq 1 5); do head -c 50000 /dev/urandom > /work/src/f$i; done
$CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite $O > /dev/null 2>&1; echo "backup 2: exit $?"
first=$(ls /work/dst | grep dlist | sort | head -1)
mv "/work/dst/$first" "/work/dst/${first/.zip.aes/.7z.aes}"
echo "renamed $first -> ${first/.zip.aes/.7z.aes}"
cp /work/db.sqlite /work/db-old.sqlite
show() { grep -iE "error|warn|fail|missing|7z|module|exception" | grep -v "^ *at " | cut -c1-260 | head -6; }
for i in $(seq 6 8); do head -c 50000 /dev/urandom > /work/src/f$i; done
echo "--- backup, existing database"; $CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite $O 2>&1 | show; echo "exit ${PIPESTATUS[0]}"
cp /work/db-old.sqlite /work/db.sqlite
echo "--- repair, existing database"; $CLI repair file:///work/dst --dbpath=/work/db.sqlite $O 2>&1 | show; echo "exit ${PIPESTATUS[0]}"
echo "--- repair, no database (recreate)"; $CLI repair file:///work/dst --dbpath=/work/db-new.sqlite $O 2>&1 | show; echo "exit ${PIPESTATUS[0]}"
echo "--- list, no database"; $CLI list file:///work/dst --no-local-db=true $O 2>&1 | head -5 | cut -c1-200
