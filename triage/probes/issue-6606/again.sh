#!/bin/bash
# Repeats the small-tmpfs restore with the build that is in place and prints the error lines
set -u
R=/root/w6606
export DOTNET_ROOT=/home/jam/.dotnet
export PATH=/home/jam/.dotnet:$PATH
export HOME=/root
CLI=$R/src/Executables/Duplicati.CommandLine/bin/Debug/net10.0/Duplicati.CommandLine.dll
for i in 1 2 3 4 5; do
  umount /mnt/r6606tmp 2>/dev/null
  mount -t tmpfs -o size=48m tmpfs /mnt/r6606tmp
  rm -rf $R/out-again; mkdir -p $R/out-again
  out=$(dotnet $CLI restore "file://$R/dest" "*" --passphrase=test-only-6606 --no-local-db=true --restore-path=$R/out-again \
    --tempdir=/mnt/r6606tmp --restore-volume-cache-min-free=8mb \
    --restore-volume-downloaders=4 --restore-volume-decryptors=4 --restore-file-processors=4 \
    --console-log-level=Warning 2>&1 | tr -d '\000')
  echo "== run $i: restored $(ls $R/out-again | wc -l)"
  echo "$out" | grep -a -E "Exception|space|Warning|Error" | grep -a -v "^   at " | head -4 | cut -c1-260
  umount /mnt/r6606tmp
done
