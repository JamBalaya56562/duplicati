#!/bin/sh
# Usage: sh -s <cli...> < run.sh   (e.g. "mono /opt/duplicati/Duplicati.CommandLine.exe" or "/opt/duplicati/duplicati-cli")
# Backs up 100,000 small files three times and prints how long each run and its consistency check took.
CLI="$*"
mkdir -p /tmp/src /tmp/dst
cd /tmp/src
for d in $(seq 0 99); do mkdir -p "d$d"; done
head -c 10000000 /dev/urandom | split -b 100 -a 5 - part
i=0
for f in part*; do mv "$f" "d$((i % 100))/$f"; i=$((i + 1)); done
echo "files: $(find /tmp/src -type f | wc -l)"
for run in 1 2 3; do
    # A few changes, so every run adds a new version
    for f in $(ls /tmp/src/d1 | head -5); do echo "$run" >> "/tmp/src/d1/$f"; done
    start=$(date +%s.%N)
    $CLI backup file:///tmp/dst /tmp/src/ --dbpath=/tmp/db.sqlite --no-encryption --log-file=/tmp/run$run.log --log-file-log-level=Profiling --console-log-level=Error > /tmp/out$run.txt 2>&1
    rc=$?
    end=$(date +%s.%N)
    echo "run $run: exit $rc, $(awk "BEGIN { printf \"%.1f\", $end - $start }") s"
    grep -a "PreBackupVerify.*took\|VerifyConsistency.*took" /tmp/run$run.log | sed 's/.*\(took [0-9:.]*\).*/  PreBackupVerify \1/' | head -2
    grep -a 'SELECT COUNT(\*) FROM (SELECT DISTINCT "Path"' /tmp/run$run.log | grep -a "took" | sed 's/.*\(took [0-9:.]*\).*/  per-version check \1/' | head -5
done
ls -la /tmp/db.sqlite | awk '{print "db bytes: " $5}'
