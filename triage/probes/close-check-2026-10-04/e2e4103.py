# Runs a backup through the server API, then a second one that is stopped partway,
# and prints the backup metadata after each run (issue #4103)
import json, os, sys, time, urllib.request

V = sys.argv[1]
BASE = "http://127.0.0.1:18300/api/v1"
password = open(os.path.join(V, "webpass.txt")).read().strip()
passphrase = open(os.path.join(V, "pass.txt")).read().strip()


def call(method, path, body=None, token=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


for _ in range(60):
    try:
        token = call("POST", "/auth/login", {"Password": password})["AccessToken"]
        break
    except Exception:
        time.sleep(1)

src = os.path.join(V, "src4103")
os.makedirs(src, exist_ok=True)
with open(os.path.join(src, "small.bin"), "wb") as f:
    f.write(os.urandom(1024 * 1024))

backup = {
    "Backup": {
        "Name": "verify-4103-" + str(int(time.time())),
        "TargetURL": "file://" + os.path.join(V, "dest4103-" + str(int(time.time()))),
        "Sources": [src + os.sep],
        "Settings": [
            {"Name": "passphrase", "Value": passphrase},
            {"Name": "dblock-size", "Value": "4mb"},
            {"Name": "throttle-upload", "Value": "512kb"},
        ],
    }
}
created = call("POST", "/backups", backup, token)
bid = str(created["ID"])
print("created backup", bid)


def run_and_wait(stop_after=None):
    task = call("POST", f"/backup/{bid}/run", None, token)["ID"]
    start = time.time()
    stopped = False
    while True:
        info = call("GET", f"/task/{task}", None, token)
        if info.get("Status") in ("Completed", "Failed"):
            return info
        if stop_after is not None and not stopped and time.time() - start > stop_after:
            call("POST", f"/task/{task}/stop", None, token)
            stopped = True
            print("  stop requested after", round(time.time() - start, 1), "s")
        time.sleep(0.5)


def show(label):
    d = call("GET", f"/backup/{bid}", None, token)
    meta = (d.get("backup") or d.get("Backup"))["Metadata"]
    keys = ["LastBackupStarted", "LastBackupFinished", "SourceFilesSize", "SourceFilesCount", "BackupListCount", "TargetFilesSize"]
    print(label, {k: meta.get(k) for k in keys})
    return meta


first = run_and_wait()
print("first run:", first.get("Status"), first.get("ErrorMessage"))
m1 = show("after first run: ")

for i in range(30):
    with open(os.path.join(src, f"big{i}.bin"), "wb") as f:
        f.write(os.urandom(1024 * 1024))

info = run_and_wait(stop_after=8)
print("second run (stopped):", info.get("Status"), info.get("ErrorMessage"))
m2 = show("after stopped run:")
log = call("GET", f"/backup/{bid}/log?pagesize=1", None, token)
if log:
    entry = log[0]
    try:
        msg = json.loads(entry.get("Message", "{}"))
        print("job log:", {k: msg.get(k) for k in ("ParsedResult", "Interrupted", "PartialBackup", "ExaminedFiles")})
    except Exception as e:
        print("job log entry:", str(entry)[:300])
print("LastBackupFinished unchanged:", m1.get("LastBackupFinished") == m2.get("LastBackupFinished"))
print("SourceFilesSize unchanged:", m1.get("SourceFilesSize") == m2.get("SourceFilesSize"))
