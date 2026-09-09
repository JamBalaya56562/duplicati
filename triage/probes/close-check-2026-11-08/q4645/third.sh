#!/bin/sh
# $1.. = the CLI command. A third backup with a 15 minute limit, after the statistics were changed.
CLI="$*"
for f in $(ls /tmp/src/d1 | head -5); do echo 3 >> "/tmp/src/d1/$f"; done
start=$(date +%s.%N)
timeout 900 $CLI backup file:///tmp/dst /tmp/src/ --dbpath=/tmp/db.sqlite --no-encryption --log-file=/tmp/run3.log --log-file-log-level=Profiling --console-log-level=Error > /tmp/out3.txt 2>&1
rc=$?
end=$(date +%s.%N)
echo "run 3: exit $rc, $(awk "BEGIN { printf \"%.1f\", $end - $start }") s (exit 124 = stopped by the 15 minute limit)"
grep -a "PreBackupVerify.*took" /tmp/run3.log | sed 's/.*\(took [0-9:.]*\).*/  PreBackupVerify \1/' | head -2
grep -a -c "ANALYZE" /tmp/run3.log | sed 's/^/  log lines with ANALYZE: /'
echo "  last query started:"
grep -a "Starting - Execute" /tmp/run3.log | tail -1 | cut -c1-400
