export PATH="$HOME/.dotnet:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
S=/mnt/c/Users/Jam/AppData/Local/Temp/claude/C--Users-Jam-Documents-duplicati/d37b421e-cf8d-4dd1-aead-0bfcff9f7dc8/scratchpad
M=/tmp/stallmnt
cd ~/dup
rsync -a --delete --exclude bin --exclude obj --exclude .jj --exclude .git /mnt/c/Users/Jam/Documents/duplicati/ ~/dup/
cp -r $S/rg-stall2/Duplicati .
dotnet build Duplicati/UnitTest/Duplicati.UnitTest.csproj -v q 2>&1 | grep -E " error " | sort -u | tail -3
for mode in ${MODES:-open getattr listxattr readdir read}; do
  fusermount3 -uz $M 2>/dev/null; rm -f /tmp/fuse-stalled; mkdir -p $M
  STALL_MODE=$mode python3 $S/stall2.py $M 2>/tmp/stall.err & FP=$!
  sleep 2
  ( sleep 100; kill -9 $FP 2>/dev/null; fusermount3 -uz $M 2>/dev/null ) & KP=$!
  echo "=== $mode"
  PROBE_SOURCE=$M/ PROBE_MARKER=/tmp/fuse-stalled timeout -s KILL 240 dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --no-build --filter "FullyQualifiedName~RedirectedStuckReadProbeTests" --logger "console;verbosity=normal" 2>&1 | grep -E "PROBEREDIR|Passed |Failed |Error Message" -A1 | grep -v "^--\|log: " | cut -c1-230
  grep -v "max threads" /tmp/stall.err | head -2
  kill -9 $FP 2>/dev/null; fusermount3 -uz $M 2>/dev/null; kill $KP 2>/dev/null; wait $FP 2>/dev/null
done
