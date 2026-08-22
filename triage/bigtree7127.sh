#!/bin/bash
# The thread's full tree: four folder levels, ten folders and ten empty files at each,
# which is 11,110 folders and 111,110 files -- the size at which the report says a backup
# runs for over twenty-four hours. Levels one to three complete here in 5s, 14s and 79s,
# so if the cost is linear this should land near thirteen minutes and if it is not it will
# not.
#
# Built with brace expansion and xargs rather than a shell loop: the recursive version
# takes about fifteen minutes at 11,110 files and would take hours at ten times that.
set -uo pipefail

ROOT="$1"
CLI="${2:-C:/Users/Jam/Documents/duplicati/Executables/Duplicati.CommandLine/bin/Debug/net10.0/Duplicati.CommandLine.dll}"

SRC="$ROOT/source"
DST="$ROOT/target"
DB="$ROOT/backup.sqlite"
LOG="$ROOT/backup.log"

rm -rf "$ROOT" 2>/dev/null
if [ -e "$ROOT" ]; then
    echo "refusing to run: $ROOT still exists after rm -rf"
    exit 1
fi
mkdir -p "$SRC" "$DST"

OPTS="--dbpath=$DB --no-encryption=true --disable-module=console-password-input"
OPTS="$OPTS --long-database-query-threshold=1s --log-file=$LOG --log-file-log-level=profiling"

# The chain down to the trigger file, and the file itself, before the first backup.
chain="$SRC/000000/000000/000000/000000"
mkdir -p "$chain"
printf '1\r\n' > "$chain/short.txt"

echo "=== backup 1: the trigger file at the bottom of four folders ==="
start=$(date +%s%3N)
mise exec dotnet -- dotnet "$CLI" backup "file://$DST" "$SRC" $OPTS 2>&1 | tail -3
echo "backup1 ms: $(( $(date +%s%3N) - start ))"
cp "$DB" "$ROOT/after-backup1.sqlite"

echo
echo "=== building the tree ==="
start=$(date +%s)
mkdir -p "$SRC"/{000000,000001,000002,000003,000004,000005,000006,000007,000008,000009}/{000000,000001,000002,000003,000004,000005,000006,000007,000008,000009}/{000000,000001,000002,000003,000004,000005,000006,000007,000008,000009}/{000000,000001,000002,000003,000004,000005,000006,000007,000008,000009}
echo "folders: $(find "$SRC" -mindepth 1 -type d | wc -l) in $(( $(date +%s) - start ))s"

start=$(date +%s)
find "$SRC" -type d -print0 \
  | xargs -0 -n 40 -P 4 -I{} sh -c 'for n in 000000 000001 000002 000003 000004 000005 000006 000007 000008 000009; do : > "$1/$n.txt"; done' _ {}
echo "files: $(find "$SRC" -type f | wc -l) in $(( $(date +%s) - start ))s"

echo
echo "=== backup 2: the tree ==="
start=$(date +%s%3N)
mise exec dotnet -- dotnet "$CLI" backup "file://$DST" "$SRC" $OPTS 2>&1 | tail -6
echo "backup2 ms: $(( $(date +%s%3N) - start ))"

echo
echo "=== slow queries reported ==="
grep -iE "slow|threshold" "$LOG" 2>/dev/null | tail -10 || echo "(none)"
echo "=== phase timers ==="
grep -oE "(Uploading a new fileset|BackupMainOperation|PreBackupVerify|AfterBackupVerify|UpdateChangeStatistics) took [0-9:.]+" "$LOG" | tail -12
echo "=== commits ==="
grep -c "Unnamed commit took" "$LOG"
awk '/Unnamed commit took/{split($NF,a,":"); s+=a[2]*3600+a[3]*60+a[4]} END{printf "unnamed commit total: %.1f s\n", s}' "$LOG"
