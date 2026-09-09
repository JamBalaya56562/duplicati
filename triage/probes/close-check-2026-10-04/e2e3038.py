# A server job with --log-file and a missing source that aborts the backup (issue #3038)
import json, os, sys, time, urllib.request

V = sys.argv[1]
BASE = "http://127.0.0.1:18300/api/v1"
password = open(os.path.join(V, "webpass.txt")).read().strip()
passphrase = open(os.path.join(V, "pass.txt")).read().strip()


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, data=None if body is None else json.dumps(body).encode(), method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


token = call("POST", "/auth/login", {"Password": password})["AccessToken"]
stamp = str(int(time.time()))
logfile = os.path.join(V, f"log3038-server-{stamp}.log")
backup = {
    "Backup": {
        "Name": "verify-3038-" + stamp,
        "TargetURL": "file://" + os.path.join(V, "dest3038-server-" + stamp),
        "Sources": [os.path.join(V, "src") + os.sep, os.path.join(V, "no-such-folder") + os.sep],
        "Settings": [
            {"Name": "passphrase", "Value": passphrase},
            {"Name": "--log-file", "Value": logfile},
            {"Name": "--log-file-log-level", "Value": "Information"},
            {"Name": "--abort-if-source-missing", "Value": "true"},
        ],
    }
}
bid = str(call("POST", "/backups", backup, token)["ID"])
task = call("POST", f"/backup/{bid}/run", None, token)["ID"]
while True:
    info = call("GET", f"/task/{task}", None, token)
    if info.get("Status") in ("Completed", "Failed"):
        break
    time.sleep(0.5)
print("task:", info.get("Status"), "|", (info.get("ErrorMessage") or "")[:160])
print("log file exists:", os.path.exists(logfile))
if os.path.exists(logfile):
    for line in open(logfile, encoding="utf-8", errors="replace"):
        if "no-such-folder" in line or "Error-" in line or "SourceIsMissing" in line:
            print("  ", line.rstrip()[:220])
