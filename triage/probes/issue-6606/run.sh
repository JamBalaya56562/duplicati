#!/bin/bash
# Runs as root in WSL: a restore whose temporary folder is a small tmpfs, before and after the change (#6606).
# The temporary folder only holds the restore cache, the restored files go elsewhere.
set -u
W=/mnt/c/Users/Jam/AppData/Local/Temp/claude/eb7164b3a8a8609a/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/w6606
R=/root/w6606
export DOTNET_ROOT=/home/jam/.dotnet
export PATH=/home/jam/.dotnet:$PATH
export HOME=/root
LOG=$W/run.log
: > $LOG
say() { echo "$*" | tee -a $LOG; }

rm -rf $R
mkdir -p $R/src || exit 1
tar -xf $W/src.tar -C $R/src || { say "extract failed"; exit 1; }
cd $R/src || exit 1
CLI=$R/src/Executables/Duplicati.CommandLine/bin/Debug/net10.0/Duplicati.CommandLine.dll
PASS=test-only-6606

# One backup for both runs, made with the fixed build (the backup is not changed)
make_backup() {
  rm -rf $R/data $R/dest
  mkdir -p $R/data $R/dest
  for i in $(seq 1 24); do head -c 3000000 /dev/urandom > $R/data/file$i.bin; done
  dotnet $CLI backup "file://$R/dest" "$R/data/" --passphrase=$PASS --dblock-size=6mb --dbpath=$R/backup.sqlite --console-log-level=Warning 2>&1 | tr -d '\000' | tail -2 | tee -a $LOG
  say "volumes: $(ls $R/dest | grep -c dblock)"
}

run() {
  local label=$1
  say "== $label"
  dotnet build Executables/Duplicati.CommandLine/Duplicati.CommandLine.csproj -v q -nologo 2>&1 | tr -d '\000' | grep -a -E ': error ' | sort -u | head -5 | tee -a $LOG
  [ -d $R/dest ] || make_backup
  umount /mnt/r6606tmp 2>/dev/null
  mkdir -p /mnt/r6606tmp
  mount -t tmpfs -o size=48m tmpfs /mnt/r6606tmp || { say "mount failed"; return; }
  rm -rf $R/out-$label
  mkdir -p $R/out-$label
  dotnet $CLI restore "file://$R/dest" "*" --passphrase=$PASS --no-local-db=true --restore-path=$R/out-$label \
    --tempdir=/mnt/r6606tmp --restore-volume-cache-min-free=8mb \
    --restore-volume-downloaders=4 --restore-volume-decryptors=4 --restore-file-processors=4 \
    --console-log-level=Warning 2>&1 | tr -d '\000' | grep -a -v '^\s*$' | grep -a -E "Restored|No space|Error|Exception:" | grep -a -v "^   at " | head -4 | tee -a $LOG
  say "restored files: $(ls $R/out-$label | wc -l), matching: $(cd $R/data && for f in *; do cmp -s $f $R/out-$label/$f && echo ok; done | wc -l)"
  umount /mnt/r6606tmp
}

cp $W/VolumeManager.fix.cs Duplicati/Library/Main/Operation/Restore/VolumeManager.cs
dotnet build Executables/Duplicati.CommandLine/Duplicati.CommandLine.csproj -v q -nologo 2>&1 | tr -d '\000' | grep -a -E ': error ' | head -3 | tee -a $LOG
make_backup
for round in 1 2 3 4 5; do
  cp $W/VolumeManager.master.cs Duplicati/Library/Main/Operation/Restore/VolumeManager.cs
  run before-$round
  cp $W/VolumeManager.fix.cs Duplicati/Library/Main/Operation/Restore/VolumeManager.cs
  run after-$round
done
say "== done"
