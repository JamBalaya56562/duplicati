#!/bin/bash
# Reproduces duplicati/duplicati#7127 with the tree the forum thread actually used.
#
# Two things this gets right that earlier attempts here did not. The tree is ten empty
# files and ten folders at every level, recursing, rather than a flat directory of files
# with content in them. And the trigger file sits in the deepest folder of the tree, so
# the first backup records the chain of folders leading down to it -- which is what puts
# folder statistics into sqlite_stat1 describing a database with a handful of rows in it.
#
# The thread reports the second backup taking 0.171s at ten folders and 159.780s at a
# hundred and ten, which is the folder count cubed.
#
# $1 root working directory, $2 folder levels (1 -> 10 folders/110 files, 2 -> 110/1110,
# 3 -> 1110/11110), $3 optional "notrigger" to leave the trigger file out of the source
set -uo pipefail

ROOT="$1"
LEVELS="$2"
MODE="${3:-trigger}"
CLI="${4:-C:/Users/Jam/Documents/duplicati/Executables/Duplicati.CommandLine/bin/Debug/net10.0/Duplicati.CommandLine.dll}"

SRC="$ROOT/source"
DST="$ROOT/target"
DB="$ROOT/backup.sqlite"
LOG="$ROOT/backup.log"

rm -rf "$ROOT" 2>/dev/null
if [ -e "$ROOT" ]; then
    echo "refusing to run: $ROOT still exists after rm -rf (a leftover destination makes"
    echo "the second backup fail with ExtraRemoteFiles instead of measuring anything)"
    exit 1
fi
mkdir -p "$SRC" "$DST"

# The slow query monitor reports any query over the threshold. Registering every query
# with it is what duplicati/duplicati#7147 fixed, so this is the instrument that issue
# asked for.
OPTS="--dbpath=$DB --no-encryption=true --disable-module=console-password-input"
OPTS="$OPTS --long-database-query-threshold=1s --log-file=$LOG --log-file-log-level=profiling"

# Ten empty files in a folder, and ten folders below it while levels remain.
build() {
    local dir="$1" left="$2" i name
    for i in 0 1 2 3 4 5 6 7 8 9; do
        : > "$dir/$(printf '%06d' "$i").txt"
    done
    if [ "$left" -gt 0 ]; then
        for i in 0 1 2 3 4 5 6 7 8 9; do
            name="$dir/$(printf '%06d' "$i")"
            mkdir -p "$name"
            build "$name" $((left - 1))
        done
    fi
}

# The chain of folders down to the deepest one, which is where the thread's trigger file
# lives. The first backup sees these folders and nothing else.
chain="$SRC"
for _ in $(seq 1 "$LEVELS"); do
    chain="$chain/000000"
done
mkdir -p "$chain"

if [ "$MODE" = "trigger" ]; then
    printf '1\r\n' > "$chain/short.txt"
    echo "=== backup 1: the trigger file at the bottom of $LEVELS folders ==="
else
    echo "=== backup 1: the folder chain with no file in it ==="
fi

start=$(date +%s%3N)
mise exec dotnet -- dotnet "$CLI" backup "file://$DST" "$SRC" $OPTS 2>&1 | tail -3
echo "backup1 ms: $(( $(date +%s%3N) - start ))"

# The statistics the second backup will plan against, before it changes anything.
cp "$DB" "$ROOT/after-backup1.sqlite"

echo
echo "=== building the tree ($LEVELS levels) ==="
build "$SRC" "$LEVELS"
echo "files: $(find "$SRC" -type f | wc -l)  folders: $(find "$SRC" -mindepth 1 -type d | wc -l)"

echo
echo "=== backup 2: the tree ==="
start=$(date +%s%3N)
mise exec dotnet -- dotnet "$CLI" backup "file://$DST" "$SRC" $OPTS 2>&1 | tail -6
echo "backup2 ms: $(( $(date +%s%3N) - start ))"

echo
echo "=== slow queries reported ==="
grep -iE "slow|threshold" "$LOG" 2>/dev/null | tail -20 || echo "(none)"
