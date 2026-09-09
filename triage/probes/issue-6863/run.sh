#!/bin/bash
# Runs as root in WSL: the report of #6863 with the command line, before and after the change.
# A folder owned by another user holds the chosen file; only the file is backed up, the folder
# is deleted, and the restore with --restore-permissions has to create it again.
set -u
W=/mnt/c/Users/Jam/AppData/Local/Temp/claude/eb7164b3a8a8609a/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/w6863
R=/root/w6863
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

run() {
  local label=$1
  say "== $label"
  dotnet build Executables/Duplicati.CommandLine/Duplicati.CommandLine.csproj -v q -nologo 2>&1 | tr -d '\000' | grep -a -E ': error ' | sort -u | head -5 | tee -a $LOG
  local T=$R/t-$label
  rm -rf $T
  mkdir -p $T/src/path $T/dest
  echo chosen > $T/src/path/file.txt
  echo other > $T/src/path/other.txt
  chown -R nobody:nogroup $T/src/path
  chmod 750 $T/src/path
  touch -d '2001-02-03 04:05:06' $T/src/path
  say "source folder: $(stat -c '%U:%G %a %y' $T/src/path)"
  dotnet $CLI backup "file://$T/dest" "$T/src/path/file.txt" --no-encryption=true --dbpath=$T/db.sqlite --console-log-level=Warning 2>&1 | tr -d '\000' | tail -3 | tee -a $LOG
  dotnet $CLI find "file://$T/dest" "*" --no-encryption=true --dbpath=$T/db.sqlite 2>&1 | tr -d '\000' | grep -a "$T" | tee -a $LOG
  rm -rf $T/src/path
  dotnet $CLI restore "file://$T/dest" "*" --no-encryption=true --dbpath=$T/db.sqlite --restore-permissions=true --console-log-level=Warning 2>&1 | tr -d '\000' | tail -3 | tee -a $LOG
  say "restored folder: $(stat -c '%U:%G %a %y' $T/src/path 2>&1)"
  say "restored entries: $(ls -A $T/src/path 2>&1 | tr '\n' ' ')"
}

cp $W/LocalFileSource.master.cs Duplicati/Library/SourceProvider/Builtin/LocalFileSource.cs
run before
cp $W/LocalFileSource.fix.cs Duplicati/Library/SourceProvider/Builtin/LocalFileSource.cs
run after
say "== done"
