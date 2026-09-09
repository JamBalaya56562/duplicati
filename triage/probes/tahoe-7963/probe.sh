set -e
pip install --quiet --no-cache-dir tahoe-lafs==1.20.0 "pyOpenSSL<24.3" >/tmp/pip.log 2>&1 || { tail -20 /tmp/pip.log; exit 1; }
tahoe --version 2>&1 | head -1

cat > /tmp/req.py <<'PY'
import sys, urllib.request, urllib.error
method, url = sys.argv[1], sys.argv[2]
data = sys.argv[3].encode() if len(sys.argv) > 3 else None
req = urllib.request.Request(url, data=data, method=method)
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        code, body = r.status, r.read()
except urllib.error.HTTPError as e:
    code, body = e.code, e.read()
except Exception as e:
    code, body = -1, str(e).encode()
if len(sys.argv) > 4 and sys.argv[4] == "body-only":
    sys.stdout.write(body.decode(errors="replace"))
else:
    print("HTTP", code)
    print(body.decode(errors="replace")[:300])
PY
req() { python /tmp/req.py "$@"; }

tahoe create-introducer --listen=tcp --port=tcp:41000 --location=tcp:127.0.0.1:41000 /intro >/dev/null
tahoe run --allow-stdin-close /intro </dev/null >/tmp/intro.log 2>&1 &
for i in $(seq 1 120); do [ -f /intro/private/introducer.furl ] && break; sleep 1; done
[ -f /intro/private/introducer.furl ] || { echo "--- intro.log"; tail -30 /tmp/intro.log; ls -R /intro | head -30; exit 1; }
FURL=$(cat /intro/private/introducer.furl)

tahoe create-node --listen=tcp --port=tcp:41001 --location=tcp:127.0.0.1:41001 --introducer="$FURL" \
  --nickname=n1 --shares-needed=1 --shares-happy=1 --shares-total=1 --webport=tcp:3456:interface=127.0.0.1 /node >/dev/null
tahoe run --allow-stdin-close /node </dev/null >/tmp/node.log 2>&1 &
for i in $(seq 1 120); do req GET 'http://127.0.0.1:3456/?t=json' "" body-only 2>/dev/null | grep -q '"connection_status": "connected"' && break; sleep 1; done
req GET 'http://127.0.0.1:3456/?t=json' "" body-only | grep -o '"connection_status": "connected"' || { echo '--- node.log'; tail -40 /tmp/node.log; echo '--- status'; req GET 'http://127.0.0.1:3456/?t=json' '' body-only | head -c 1500; exit 1; }

DIR=$(req POST 'http://127.0.0.1:3456/uri?t=mkdir' "" body-only)
echo "dircap: ${DIR:0:14}..."
B=http://127.0.0.1:3456/uri/$DIR

echo "== put a file";                 req PUT    "$B/file.txt" "content"
echo "== delete an existing file";    req DELETE "$B/file.txt"
echo "== delete a missing file";      req DELETE "$B/file.txt"
echo "== delete in a missing folder"; req DELETE "$B/nofolder/file.txt"
echo "== list a missing folder";      req GET    "$B/nofolder?t=json"
