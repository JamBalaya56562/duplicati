#!/usr/bin/env bash
# #7717: related tests on the branch, then kill compact at a random point and run compact again.
JJ="$HOME/AppData/Local/mise/installs/jj/latest/jj.exe"
D="$HOME/AppData/Local/mise/dotnet-root/dotnet.exe"
S="C:/Users/Jam/AppData/Local/Temp/claude/56e8f38302861c8b/7684422f-f916-47ff-b1d3-177d9133cd4e/scratchpad"
W="$S/kill"
OUT="$S/compact-kill.log"
BR=fix/compact-cleans-up-after-stopped-upload
CLI=Executables/Duplicati.CommandLine/Duplicati.CommandLine.csproj
cd /c/Users/Jam/Documents/duplicati || exit 1
: > "$OUT"

"$JJ" new "$BR" >/dev/null 2>&1 || { echo "jj new failed" >> "$OUT"; exit 1; }
mkdir -p "$W"
"$D" build "$CLI" -c Debug -v q -nologo -o "$W/cli-branch" > "$S/b.log" 2>&1; echo "cli-branch build rc=$?" >> "$OUT"
"$JJ" new master >/dev/null 2>&1
"$D" build "$CLI" -c Debug -v q -nologo -o "$W/cli-master" > "$S/b.log" 2>&1; echo "cli-master build rc=$?" >> "$OUT"
"$JJ" new master >/dev/null 2>&1

EXE_M="$W/cli-master/Duplicati.CommandLine.exe"; EXE_B="$W/cli-branch/Duplicati.CommandLine.exe"
ls "$EXE_M" "$EXE_B" >> "$OUT" 2>&1 || exit 1

# Template: partly wasted volumes, so compact downloads and uploads
SRC="$W/src"; T="$W/template"; R="$W/run"
rm -rf "$W/src" "$W/template" "$W/run"; mkdir -p "$SRC" "$T/dest" "$R"
for i in $(seq 1 800); do head -c 262144 /dev/urandom > "$SRC/f$i.bin"; done
opts() { echo "--no-encryption=true --dblock-size=2mb --dbpath=$1/db.sqlite --no-auto-compact=true --console-log-level=Warning"; }
TU="file://$T/dest"
"$EXE_M" backup "$TU" "$SRC" $(opts "$T") --keep-versions=0 > "$S/tpl1.log" 2>&1; echo "template backup1 rc=$?" >> "$OUT"
for i in $(seq 1 2 800); do : > "$SRC/f$i.bin"; done
find "$SRC" -size 0 -delete
"$EXE_M" backup "$TU" "$SRC" $(opts "$T") > "$S/tpl2.log" 2>&1; echo "template backup2 rc=$?" >> "$OUT"
"$EXE_M" delete "$TU" --version=1 --allow-full-removal=false $(opts "$T") > "$S/tpl3.log" 2>&1; echo "template delete rc=$?" >> "$OUT"
echo "template files: $(ls "$T/dest" | wc -l), size $(du -sm "$T/dest" | cut -f1) MB" >> "$OUT"
[ "$(ls "$T/dest" | wc -l)" -gt 20 ] || { echo "TEMPLATE-FAILED" >> "$OUT"; tail -3 "$S/tpl1.log" >> "$OUT"; exit 1; }

restore() { rm -rf "$W/run/dest" "$W/run/db.sqlite"; cp -r "$T/dest" "$W/run/dest"; cp "$T/db.sqlite" "$W/run/db.sqlite"; }

restore
st=$(date +%s%N); "$EXE_M" compact "file://$R/dest" $(opts "$R") > "$S/dur.log" 2>&1; rc=$?; en=$(date +%s%N)
echo "uninterrupted compact on master: rc=$rc $(( (en-st)/1000000 )) ms" >> "$OUT"
tail -3 "$S/dur.log" | cut -c1-160 >> "$OUT"
[ "$rc" = 0 ] || { echo "COMPACT-BASELINE-FAILED" >> "$OUT"; exit 1; }
[ "$(( (en-st)/1000000 ))" -gt 3500 ] || { echo "COMPACT-TOO-SHORT" >> "$OUT"; exit 1; }

round() { # exe label n
  restore
  ms=$(( 300 + RANDOM % 3201 ))
  "$1" compact "file://$R/dest" $(opts "$R") > "$S/first.log" 2>&1 &
  pid=$!
  sleep "$(awk "BEGIN{print $ms/1000}")"
  finished=no
  if kill -0 "$pid" 2>/dev/null; then
    wp=$(cat /proc/$pid/winpid 2>/dev/null)
    taskkill //F //T //PID "$wp" > /dev/null 2>&1
  else
    finished=yes
  fi
  wait "$pid" 2>/dev/null
  "$1" compact "file://$R/dest" $(opts "$R") > "$S/second.log" 2>&1; rc=$?
  msg=$(grep -aE 'strict mode|has failed|=> ' "$S/second.log" | head -1 | sed -E 's/duplicati-[^ ]+/<file>/' | cut -c1-110)
  echo "$2 $3 kill=${ms}ms finishedBeforeKill=$finished rc=$rc $msg" >> "$S/rounds.log"
}

: > "$S/rounds.log"
for n in $(seq 1 70); do round "$EXE_M" master "$n"; round "$EXE_B" branch "$n"; done
for n in $(seq 71 120); do round "$EXE_B" branch "$n"; done

for l in master branch; do
  a=$(grep -c "^$l " "$S/rounds.log")
  f=$(grep "^$l " "$S/rounds.log" | grep -vc ' rc=0 ')
  k=$(grep "^$l " "$S/rounds.log" | grep -c 'finishedBeforeKill=no')
  echo "$l rounds=$a killedMidRun=$k followUpNonZero=$f" >> "$OUT"
  grep "^$l " "$S/rounds.log" | grep -v ' rc=0 ' | sed -E 's/^.* rc=([0-9]+) /rc=\1 /' | sort | uniq -c | sort -rn | head -6 >> "$OUT"
done
echo DONE >> "$OUT"
cat "$OUT"
