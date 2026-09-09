#!/bin/bash
# Usage: probe2.sh <bin dir> <data dir> <label>
# Starts an isolated server on 127.0.0.1:8399, lists folders with links and stops the server again.
S=/c/Users/Jam/AppData/Local/Temp/claude/8062b0f02d09eafd/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/junction636
BIN=$1; DATA=$2; LABEL=$3
PORT=8399
export DOTNET_ROOT='C:\Users\Jam\AppData\Local\mise\dotnet-root'
PW=$(cat $S/pw.txt)
OUT=$S/result-$LABEL.txt
: > $OUT

"$BIN/Duplicati.Server.exe" --server-datafolder="$(cygpath -w "$DATA")" --webservice-port=$PORT --webservice-interface=loopback \
  --webservice-password="$PW" --disable-update-check=true --log-file="$(cygpath -w "$S/server-$LABEL.log")" --log-level=Information \
  > $S/server-$LABEL.stdout 2>&1 &
SRV=$!

for i in $(seq 1 120); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break
  sleep 1
done

TOKEN=$(curl -s -X POST "http://127.0.0.1:$PORT/api/v1/auth/login" -H 'Content-Type: application/json' \
  -d "{\"Password\":\"$PW\"}" | sed -n 's/.*"AccessToken":"\([^"]*\)".*/\1/p')
[ -z "$TOKEN" ] && echo "login failed" >> $OUT

list() {
  echo "LIST $1" >> $OUT
  curl -s -X POST "http://127.0.0.1:$PORT/api/v1/filesystem?onlyFolders=true&showHidden=true" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary "$1" \
    | tr '}' '\n' | grep -E '"symlink":true' \
    | sed -E 's/.*"text":"([^"]*)".*"resolvedpath":("[^"]*"|null).*/\1 | resolvedpath=\2 | &/' \
    | sed -E 's/ \| \{?,?\{?"text.*("symlinkTarget":("[^"]*"|null)).*/ | \1/; s/ \| [{,]?"text.*/ | (no symlinkTarget)/' >> $OUT
}

list '{"path":"%HOME%\\"}'
list '{"path":"C:\\Users\\Jam\\"}'
list '{"path":"C:\\Users\\Jam\\AppData\\Local\\Temp\\claude\\8062b0f02d09eafd\\2ade3d67-588b-4a0d-82ef-8acf31aad402\\scratchpad\\junction636\\own\\"}'

kill $SRV 2>/dev/null
sleep 2
kill -9 $SRV 2>/dev/null
wait $SRV 2>/dev/null
echo "server stopped" >> $OUT
cat $OUT
