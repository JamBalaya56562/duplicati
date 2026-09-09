#!/bin/sh
# $1.. = the CLI command. Creates 100,000 small files and backs them up twice.
CLI="$*"
mkdir -p /tmp/src /tmp/dst
cd /tmp/src
for d in $(seq 0 99); do mkdir -p "d$d"; done
head -c 10000000 /dev/urandom | split -b 100 -a 5 - part
i=0
for f in part*; do mv "$f" "d$((i % 100))/$f"; i=$((i + 1)); done
echo "files: $(find /tmp/src -type f | wc -l)"
for run in 1 2; do
    for f in $(ls /tmp/src/d1 | head -5); do echo "$run" >> "/tmp/src/d1/$f"; done
    $CLI backup file:///tmp/dst /tmp/src/ --dbpath=/tmp/db.sqlite --no-encryption --console-log-level=Error > "/tmp/out$run.txt" 2>&1
    echo "run $run exit $?"
done
