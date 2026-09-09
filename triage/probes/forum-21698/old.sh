#!/bin/bash
# forum 21698, step 1 (2.0.6.1, which still has 7z): one backup with 7z, then one with zip, to the same destination
CLI="$*"
mkdir -p /work/src /work/dst
for i in $(seq 1 20); do head -c 50000 /dev/urandom > /work/src/f$i; done
$CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite --passphrase=test1234 --compression-module=7z --console-log-level=Error > /work/b1.txt 2>&1; echo "backup with 7z: exit $?"
for i in $(seq 1 5); do head -c 50000 /dev/urandom > /work/src/f$i; done
$CLI backup file:///work/dst /work/src/ --dbpath=/work/db.sqlite --passphrase=test1234 --compression-module=zip --console-log-level=Error > /work/b2.txt 2>&1; echo "backup with zip: exit $?"
ls /work/dst | sed 's/^duplicati-[0-9TZ]*\.//; s/^duplicati-[a-z0-9]*\.//' | sort | uniq -c
