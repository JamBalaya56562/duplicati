export PATH="$HOME/.dotnet:$PATH"
export DOTNET_ROOT="$HOME/.dotnet"
S=/mnt/c/Users/Jam/AppData/Local/Temp/claude/C--Users-Jam-Documents-duplicati/d37b421e-cf8d-4dd1-aead-0bfcff9f7dc8/scratchpad/verify
WORK=$HOME/verify2004
rm -rf "$WORK"; mkdir -p "$WORK"
~/dup/Executables/Duplicati.Server/bin/Debug/net10.0/Duplicati.Server --webservice-port=18301 --server-datafolder="$WORK/srvdata" --webservice-interface=loopback --disable-db-encryption=true --webservice-password="$(cat $S/webpass.txt)" > "$WORK/server.log" 2>&1 &
SRV=$!
for i in $(seq 1 60); do curl -s -m 2 -o /dev/null http://127.0.0.1:18301/ && break; sleep 1; done
PYTHONIOENCODING=utf-8 timeout 500 python3 "$S/e2e2004-linux.py" "$S" "$WORK" 2>&1 | tail -14
kill $SRV
