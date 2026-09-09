#!/bin/bash
# Issue #2931: time of the wasted-space report (the "UsageReport" query run by compact).
# $1.. = the CLI command. Runs in a fresh container.
# 20,000 files of 20 KB in 100 folders with 1 KB blocks (about 20 blocks per file, the shape of the
# synthetic database in #7340), then 40 versions that each change 200 files, then a compact with
# the Profiling log. The time of the compact and of every query that mentions UsageReport is printed.
CLI="$*"
COMMON="--dbpath=/tmp/db.sqlite --no-encryption --blocksize=1kb --keep-versions=0 --no-auto-compact=true --console-log-level=Error"
mkdir -p /tmp/src
for d in $(seq 1 100); do
    mkdir -p /tmp/src/d$d
    for f in $(seq 1 200); do head -c 20480 /dev/urandom > /tmp/src/d$d/f$f; done
done
start=$(date +%s)
for v in $(seq 1 40); do
    for f in $(seq 1 200); do head -c 20480 /dev/urandom > /tmp/src/d$(( (v + f) % 100 + 1 ))/f$f; done
    $CLI backup file:///tmp/dst /tmp/src/ $COMMON > /tmp/backup-$v.txt 2>&1 || { echo "backup $v failed"; tail -5 /tmp/backup-$v.txt; }
done
echo "40 backups took $(( $(date +%s) - start )) s; versions: $($CLI list file:///tmp/dst $COMMON 2>/dev/null | grep -c '^[0-9]')"
echo "database: $(du -m /tmp/db.sqlite | cut -f1) MB"
for run in 1 2; do
    s=$(date +%s.%N)
    $CLI compact file:///tmp/dst $COMMON --log-file=/tmp/compact-$run.log --log-file-log-level=Profiling > /tmp/compact-$run.txt 2>&1
    rc=$?
    e=$(date +%s.%N)
    echo "compact $run: exit $rc, $(awk "BEGIN { printf \"%.1f\", $e - $s }") s"
    grep -a "took" /tmp/compact-$run.log | grep -a -i "UsageReport\|BlocksetTime" | sed 's/.*\(took [0-9:.]*\).*/  \1/' | sort | uniq -c | sort -rn | head -5
    grep -a "took" /tmp/compact-$run.log | sed -n 's/.*took \([0-9]*\):\([0-9]*\):\([0-9]*\):\([0-9.]*\).*/\1 \2 \3 \4/p' | awk '{ t = $1*86400 + $2*3600 + $3*60 + $4; if (t > m) m = t } END { printf "  slowest timed step: %.2f s\n", m }'
done
