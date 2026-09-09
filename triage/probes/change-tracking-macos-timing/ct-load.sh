#!/bin/bash
# Runs the change-tracking tests N times while busy loops load every core, and counts the failures per test.
# $1 = runs, $2 = busy loops, $3 = label
RUNS=${1:-10}; LOAD=${2:-16}; LABEL=${3:-run}
cd /c/Users/Jam/Documents/duplicati
DOTNET=/c/Users/Jam/AppData/Local/mise/dotnet-root/dotnet.exe
DLL=Duplicati/UnitTest/bin/Debug/net10.0/Duplicati.UnitTest.dll
OUT=/c/Users/Jam/AppData/Local/Temp/claude/eb7164b3a8a8609a/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/ct-$LABEL
mkdir -p $OUT; rm -f $OUT/*.txt
pids=()
cleanup() { for p in "${pids[@]}"; do kill $p 2>/dev/null; done; }
trap cleanup EXIT
for i in $(seq $LOAD); do ( while :; do :; done ) & pids+=($!); done
for r in $(seq $RUNS); do
  $DOTNET test $DLL --filter "FullyQualifiedName~ChangeTrackingServiceTests" > $OUT/run$r.txt 2>&1
  echo "run $r: $(grep -aE '^\s+(失敗|Failed) [A-Za-z_]' $OUT/run$r.txt | sed 's/\[.*//' | tr -s ' ' | tr '\n' ';')"
done
echo "== failures per test ($LABEL, $RUNS runs, $LOAD busy loops)"
cat $OUT/run*.txt | grep -aE '^\s+(失敗|Failed) [A-Za-z_]' | sed 's/\[.*//; s/^ *//' | sort | uniq -c
grep -ahE '合計|Total tests|テストの合計数' $OUT/run1.txt
