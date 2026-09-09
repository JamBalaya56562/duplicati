export PATH="$HOME/.dotnet:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
S=/mnt/c/Users/Jam/AppData/Local/Temp/claude/C--Users-Jam-Documents-duplicati/d37b421e-cf8d-4dd1-aead-0bfcff9f7dc8/scratchpad
M=/tmp/stallmnt
cd ~/dup
rsync -a --delete --exclude bin --exclude obj --exclude .jj --exclude .git /mnt/c/Users/Jam/Documents/duplicati/ ~/dup/
cp -r $S/rg-a3trace/Duplicati .
dotnet build Duplicati/UnitTest/Duplicati.UnitTest.csproj -v q 2>&1 | grep -E " error " | sort -u | tail -3
for c in "getattr 13" "getattr 30" "getattr 40" "listxattr 2"; do
  set -- $c; mode=$1; k=$2
  fusermount3 -uz $M 2>/dev/null; rm -f /tmp/fuse-stalled /tmp/stall-trace.log; mkdir -p $M
  STALL_MODE=$mode STALL_AFTER=$k python3 $S/stall2.py $M 2>/tmp/stall.err & FP=$!
  sleep 2
  ( sleep 100; kill -9 $FP 2>/dev/null; fusermount3 -uz $M 2>/dev/null ) & KP=$!
  r=$(PROBE_SOURCE=$M/ PROBE_MARKER=/tmp/fuse-stalled timeout -s KILL 240 dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --no-build --filter "FullyQualifiedName~RedirectedStuckReadProbeTests" --logger "console;verbosity=normal" 2>&1 | grep -E "returned within" | sed 's/PROBEREDIR //' | cut -c1-80)
  echo "=== $mode after $k: $r / $(grep -v 'max threads' /tmp/stall.err | head -1)"
  echo "--- trace (stat sites entered but not left):"
  python3 - <<'PY'
lines = [l.split(" ", 1)[1].rsplit(" ", 1)[0] for l in open("/tmp/stall-trace.log")] if __import__("os").path.exists("/tmp/stall-trace.log") else []
open_sites = {}
for l in lines:
    site, edge = l.rsplit(" ", 1)
    open_sites[site] = open_sites.get(site, 0) + (1 if edge == "before" else -1)
print("  all marks:", len(lines), "| stuck in:", [s for s, n in open_sites.items() if n > 0])
PY
  kill -9 $FP 2>/dev/null; fusermount3 -uz $M 2>/dev/null; kill $KP 2>/dev/null; wait $FP 2>/dev/null
done
