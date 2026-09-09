# Usage: python3 probe.py <server dll> <data dir> <remote folder> <restore folder or ""> <label> <list: true|false> <copytotemp: 0|1> <documents path>
# The same steps as probe.mjs, for a server on Linux: a temporary job as for a direct restore in ngclient,
# repairupdate with only_paths, list-folder, and optionally a restore of Documents.
import json, os, subprocess, sys, time, urllib.request

dll, data, remote, restore_to, label, list_first, copy, docs = sys.argv[1:9]
port = 8398
base = f"http://127.0.0.1:{port}"
here = os.path.dirname(os.path.abspath(__file__))
password = open(os.path.join(here, "pw.txt")).read().strip()
out = []

def log(k, v):
    line = f"{k} {v if isinstance(v, str) else json.dumps(v, ensure_ascii=False)}"
    out.append(line)
    print(line, flush=True)

env = dict(os.environ, DOTNET_ROOT=os.path.expanduser("~/.dotnet"))
server = subprocess.Popen([os.path.expanduser("~/.dotnet/dotnet"), dll, f"--server-datafolder={data}", f"--webservice-port={port}",
    "--webservice-interface=loopback", f"--webservice-password={password}", "--disable-update-check=true",
    "--disable-db-encryption=true", f"--log-file={os.path.join(here, 'server-' + label + '.log')}", "--log-level=Information"],
    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def call(method, url, body=None, token=None):
    req = urllib.request.Request(base + url, method=method, data=None if body is None else json.dumps(body).encode())
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            text = r.read().decode()
            status = r.status
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        status = e.code
    try:
        return status, json.loads(text)
    except Exception:
        return status, None

def wait_task(task_id, token):
    for _ in range(120):
        _, s = call("GET", f"/api/v1/task/{task_id}", token=token)
        if s and s.get("Status") in ("Failed", "Completed"):
            return s
        time.sleep(1)
    return s

try:
    for _ in range(120):
        try:
            urllib.request.urlopen(base + "/")
            break
        except Exception:
            time.sleep(1)
    _, login = call("POST", "/api/v1/auth/login", {"Password": password})
    token = login["AccessToken"]

    _, created = call("POST", "/api/v1/backups?temporary=true", {"Backup": {"TargetURL": "file://" + remote, "Settings": [{"Name": "--no-encryption", "Value": "true"}]}}, token)
    job = created["ID"]
    log("temporary-job", {"id": job})

    when = None
    if list_first == "true":
        _, sets = call("POST", "/api/v2/backup/list-filesets", {"BackupId": job}, token)
        when = sets["Data"][0]["Time"]
        _, rep = call("POST", f"/api/v1/backup/{job}/repairupdate", {"only_paths": True, "time": when}, token)
        st = wait_task(rep["ID"], token)
        log("repairupdate", {"task": st.get("Status"), "error": st.get("ErrorMessage")})
        listing = {"BackupId": job, "Time": when, "PageSize": 0, "Page": 0, "ReturnExtended": True}
        s, roots = call("POST", "/api/v2/backup/list-folder", dict(listing, Paths=None), token)
        log("roots", {"status": s, "success": roots.get("Success"), "error": roots.get("Error"), "data": [{"Path": x["Path"], "IsDirectory": x["IsDirectory"]} for x in roots.get("Data") or []]})
        root = roots["Data"][0]["Path"]
        s, children = call("POST", "/api/v2/backup/list-folder", dict(listing, Paths=[root]), token)
        log("children", {"request": root, "status": s, "success": children.get("Success"), "data": [{"Path": x["Path"], "IsDirectory": x["IsDirectory"]} for x in children.get("Data") or []]})
        folder = next((x["Path"] for x in children.get("Data") or [] if x["IsDirectory"]), None)
        if folder:
            s, nested = call("POST", "/api/v2/backup/list-folder", dict(listing, Paths=[folder]), token)
            log("documents", {"request": folder, "status": s, "data": [{"Path": x["Path"], "IsDirectory": x["IsDirectory"]} for x in nested.get("Data") or []]})

    if restore_to:
        rid = job
        if copy == "1":
            _, c = call("POST", f"/api/v1/backup/{job}/copytotemp", None, token)
            rid = c["ID"]
            log("copytotemp", {"id": rid})
        body = {"paths": [docs], "restore_path": restore_to, "overwrite": True, "permissions": False}
        if when:
            body["time"] = when
        log("restore-request", {"id": rid, "body": body})
        _, started = call("POST", f"/api/v1/backup/{rid}/restore", body, token)
        st = wait_task(started["ID"], token)
        log("restore-task", {"status": st.get("Status"), "error": st.get("ErrorMessage")})
        files = []
        for d, _, names in os.walk(restore_to):
            for n in names:
                p = os.path.join(d, n)
                files.append({"p": os.path.relpath(p, restore_to), "content": open(p, encoding="utf-8").read()})
        log("restored-files", files)
finally:
    server.terminate()
    try:
        server.wait(10)
    except Exception:
        server.kill()
    open(os.path.join(here, f"result-{label}.txt"), "w").write("\n".join(out) + "\n")
