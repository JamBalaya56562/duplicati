#!/bin/bash
# Usage: probe.sh <bin dir> <data dir> <label>
# Starts an isolated server on 127.0.0.1:8399, calls the filesystem API and stops the server again.
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

UP=$(cygpath -w "$USERPROFILE" 2>/dev/null || echo "C:\\Users\\Jam")
call() {
  local body=$1
  local res
  res=$(curl -s -w ' HTTP=%{http_code}' -X POST "http://127.0.0.1:$PORT/api/v1/filesystem?onlyFolders=true&showHidden=true" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary "$body")
  echo "REQ $body" >> $OUT
  echo "RES ${res:0:600}" >> $OUT
}

call '{"path":"%HOME%\\Cookies\\"}'
call '{"path":"C:\\Users\\Jam\\Cookies\\"}'
call '{"path":"%HOME%\\Application Data\\"}'
call '{"path":"C:\\Users\\Jam\\AppData\\Local\\Microsoft\\Windows\\INetCookies\\"}'
call '{"path":"%HOME%\\AppData\\Local\\Microsoft\\Windows\\INetCookies\\"}'
OWN='C:\\Users\\Jam\\AppData\\Local\\Temp\\claude\\8062b0f02d09eafd\\2ade3d67-588b-4a0d-82ef-8acf31aad402\\scratchpad\\junction636\\own'
call "{\"path\":\"$OWN\\\\link\\\\\"}"
call "{\"path\":\"$OWN\\\\target\\\\\"}"
curl -s -X POST "http://127.0.0.1:$PORT/api/v1/filesystem?onlyFolders=true&showHidden=true" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary "{\"path\":\"$OWN\\\\\"}" \
  | tr '}' '\n' | grep -E '"text":"link"' >> $OUT
# The parent listing: how is Cookies reported there?
curl -s -X POST "http://127.0.0.1:$PORT/api/v1/filesystem?onlyFolders=true&showHidden=true" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary '{"path":"%HOME%\\"}' \
  | tr '}' '\n' | grep -E '"text":"(Cookies|Application Data|AppData)"' >> $OUT

kill $SRV 2>/dev/null
sleep 2
kill -9 $SRV 2>/dev/null
wait $SRV 2>/dev/null
echo "server stopped" >> $OUT
cat $OUT
