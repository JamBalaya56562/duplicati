#!/bin/bash
# Asks whether a backup that completed normally leaves its own dlist volume in a state
# the next backup reads as "the previous one was interrupted" -- which is what makes the
# first interrupted run of the macOS flake upload a fileset it should have skipped.
#
# A fresh directory per run: rm -rf does not reliably clear a destination on Windows, and
# a leftover one makes the next backup fail with ExtraRemoteFiles instead of measuring.
set -uo pipefail

ROOT="$1"
RUNS="${2:-12}"
CLI="C:/Users/Jam/Documents/duplicati/Executables/Duplicati.CommandLine/bin/Debug/net10.0/Duplicati.CommandLine.dll"
CHECK="/w/incomplete-check.py"
SCRATCH="/c/Users/Jam/AppData/Local/Temp/claude/C--Users-Jam-Documents-duplicati/e8cd3eb2-d741-45d7-9807-bd58091a49cf/scratchpad"

mkdir -p "$ROOT"
found=0

for i in $(seq 1 "$RUNS"); do
    d="$ROOT/run-$i"
    mkdir -p "$d/source" "$d/target"
    for f in 1 2 3; do printf 'content %d\n' "$f" > "$d/source/file$f.txt"; done

    mise exec dotnet -- dotnet "$CLI" backup "file://$d/target" "$d/source" \
        --dbpath="$d/db.sqlite" --no-encryption=true \
        --disable-module=console-password-input > "$d/backup.log" 2>&1
    rc=$?

    out=$(MSYS_NO_PATHCONV=1 docker run --rm -i -v "$SCRATCH:/w" -v "/c/Temp:/t" \
        python:3.12-slim python -u "$CHECK" "/t/${d#/c/Temp/}/db.sqlite" 2>&1 | tail -1)

    echo "run $i: rc=$rc  $out"
    case "$out" in
        incomplete=0*) ;;
        *) found=$((found + 1)) ;;
    esac
done

echo
echo "runs leaving a fileset the next backup would call interrupted: $found of $RUNS"
