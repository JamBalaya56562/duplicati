# Backs up names with an emoji, a comma and an equals sign, lists them the ways both UIs do,
# and restores them through the server API (issue #2004)
import json, os, sys, time, urllib.parse, urllib.request

V = sys.argv[1]
BASE = "http://127.0.0.1:18301/api"
WORK = sys.argv[2]
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


token = call("POST", "/v1/auth/login", {"Password": password})["AccessToken"]
stamp = str(int(time.time()))
src = os.path.join(WORK, "run/user/1000/gvfs", "src2004-" + stamp)
names = {
    os.path.join("Notes \U0001F4DD", "file1.txt"): "emoji 1",
    os.path.join("Notes \U0001F4DD", "file2.txt"): "emoji 2",
    os.path.join("sftp:host=http,user=root", "file3.txt"): "comma",
    os.path.join("ASCII", "in-ascii.txt"): "ascii",
}
for rel, text in names.items():
    os.makedirs(os.path.dirname(os.path.join(src, rel)), exist_ok=True)
    open(os.path.join(src, rel), "w", encoding="utf-8").write(text)

backup = {"Backup": {
    "Name": "verify-2004-" + stamp,
    "TargetURL": "file://" + os.path.join(WORK, "dest2004-" + stamp),
    "Sources": [src + os.sep],
    "Settings": [{"Name": "passphrase", "Value": passphrase}],
}}
bid = str(call("POST", "/v1/backups", backup, token)["ID"])


def wait(task):
    while True:
        info = call("GET", f"/v1/task/{task}", None, token)
        if info.get("Status") in ("Completed", "Failed"):
            return info
        time.sleep(0.5)


print("backup:", wait(call("POST", f"/v1/backup/{bid}/run", None, token)["ID"]).get("Status"))

# New UI: list-folder
for folder in [src + os.sep, os.path.join(src, "Notes \U0001F4DD") + os.sep, os.path.join(src, "sftp:host=http,user=root") + os.sep]:
    res = call("POST", "/v2/backup/list-folder", {"BackupId": bid, "Paths": [folder], "Time": None, "PageSize": 1000, "Page": 0}, token)
    items = res.get("Data") or res.get("data") or []
    print("v2 list-folder", repr(os.path.basename(folder.rstrip(os.sep))), "->", sorted(os.path.basename(i["Path"].rstrip(os.sep)) for i in items))

# Old UI: '@' + path with folder-contents
for folder in [src + os.sep, os.path.join(src, "Notes \U0001F4DD") + os.sep, os.path.join(src, "sftp:host=http,user=root") + os.sep]:
    q = urllib.parse.urlencode({"filter": "@" + folder, "time": "now", "prefix-only": "false", "folder-contents": "true"})
    try:
        res = call("GET", f"/v1/backup/{bid}/files?{q}", None, token)
        files = res.get("Files") or []
        print("v1 files @", repr(os.path.basename(folder.rstrip(os.sep))), "->", sorted(os.path.basename(f["Path"].rstrip(os.sep)) for f in files))
    except urllib.error.HTTPError as e:
        print("v1 files @", repr(folder), "-> HTTP", e.code, e.read()[:300])

# Restore the files and, separately, a whole folder
import re
emoji_dir = os.path.join(src, "Notes 📝") + os.sep
comma_dir = os.path.join(src, "sftp:host=http,user=root") + os.sep
f1 = os.path.join(src, "Notes 📝", "file1.txt")
f3 = os.path.join(src, "sftp:host=http,user=root", "file3.txt")
def ngax_folder(d):
    # Same as the old UI: item.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    bs = chr(92)
    special = set(".*+?^${}()|[]" + bs)
    return "[" + "".join(bs + c if c in special else c for c in d) + ".*]"
for label, paths in [
    ("ngclient-files", [f1, f3]),
    ("ngclient-folders", [emoji_dir + "*", comma_dir + "*"]),
    ("ngax-files", ["@" + f1, "@" + f3]),
    ("ngax-folders", [ngax_folder(emoji_dir), ngax_folder(comma_dir)]),
]:
    target = os.path.join(WORK, f"restore2004-{label}-{stamp}")
    info = wait(call("POST", f"/v1/backup/{bid}/restore", {"paths": paths, "passphrase": None, "time": "now", "restore_path": target, "overwrite": True, "permissions": False, "skip_metadata": False, "connection_string_id": None, "source_prefix": None}, token)["ID"])
    found = []
    for root, _, files in os.walk(target):
        for f in files:
            p = os.path.join(root, f)
            found.append((os.path.relpath(p, target), open(p, encoding="utf-8").read()))
    print(f"restore {label}:", info.get("Status"), sorted(found))
