#!/bin/bash
# Issue #3733: does a restore write a large file front to back, or jump around in it?
# $1.. = the CLI command. Runs in a fresh container.
# One 300 MB random file, 100 KB blocks, 5 MB dblocks (about 60 volumes). The source is deleted
# before the restore, so every block comes from the backup. While the restore runs, the write
# position of every file descriptor that points at the restored file is sampled from
# /proc/<pid>/fdinfo; a position lower than the previous sample of the same descriptor is a
# jump back.
CLI="$*"
mkdir -p /tmp/src /tmp/out
head -c 300M /dev/urandom > /tmp/src/big.bin
want=$(sha256sum /tmp/src/big.bin | cut -d' ' -f1)
$CLI backup file:///tmp/dst /tmp/src/ --dbpath=/tmp/db.sqlite --no-encryption --blocksize=100kb --dblock-size=5mb --console-log-level=Error > /tmp/backup.txt 2>&1
echo "backup exit $?, volumes: $(ls /tmp/dst | grep -c dblock)"
rm -f /tmp/src/big.bin

$CLI restore file:///tmp/dst '*' --restore-path=/tmp/out --dbpath=/tmp/db.sqlite --no-encryption --console-log-level=Error > /tmp/restore.txt 2>&1 &
rpid=$!
target=/tmp/out/big.bin
: > /tmp/samples.txt; : > /tmp/sizes.txt
while kill -0 $rpid 2>/dev/null; do
    # .NET writes with pwrite, which does not move the descriptor position, so the size and the
    # allocated bytes are sampled too: a file written front to back has no holes, so the two stay
    # close; a write far ahead leaves a hole before it, and the size runs ahead of the allocation
    for k in $(seq 1 200); do
        stat -c '%s %b' "$target" >> /tmp/sizes.txt 2>/dev/null
    done
    for fd in /proc/[0-9]*/fd/*; do
        [ "$(readlink "$fd" 2>/dev/null)" = "$target" ] || continue
        p=${fd%/fd/*}; n=${fd##*/}
        pos=$(sed -n 's/^pos:[[:space:]]*//p' "$p/fdinfo/$n" 2>/dev/null)
        [ -n "$pos" ] && echo "${p#/proc/}:$n $pos" >> /tmp/samples.txt
    done
done
wait $rpid
echo "restore exit $?"
got=$(sha256sum "$target" 2>/dev/null | cut -d' ' -f1)
echo "restored file matches: $([ "$got" = "$want" ] && echo yes || echo no)"
awk '{ if ($1 in last) { if ($2 < last[$1]) back++; else if ($2 > last[$1]) fwd++ } else d++; last[$1]=$2; n++ }
     END { printf "fd position: samples %d, descriptors %d, moved forward %d, jumped back %d\n", n, d, fwd, back }' /tmp/samples.txt
awk '{ size = $1; alloc = $2 * 512; gap = size - alloc; if (gap > maxgap) { maxgap = gap; atsize = size; atalloc = alloc }
       if (NR > 1 && size != prev) ch++; prev = size; n++ }
     END { if (n == 0) { print "file size: no samples"; exit }
           printf "size/allocation: samples %d, size changes %d, largest (size - allocated) %.1f MB (size %.1f MB, allocated %.1f MB)\n",
             n, ch, maxgap/1048576, atsize/1048576, atalloc/1048576 }' /tmp/sizes.txt
echo "first positions (MB):"; awk '{ printf "%.1f ", $2/1048576 } NR==25 { exit }' /tmp/samples.txt; echo
