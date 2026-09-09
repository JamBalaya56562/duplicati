#!/usr/bin/env python3
"""What does the advice "use purge-broken-files" do on a database whose recreate was killed?
usage: inprogress.py <cli> <workdir> <kill-after-seconds>"""
import os, sys, shutil, subprocess, sqlite3, signal, time

CLI, WORK, DELAY = sys.argv[1], sys.argv[2], float(sys.argv[3])
shutil.rmtree(WORK, ignore_errors=True)
SRC, DST, DB = (os.path.join(WORK, x) for x in ("src", "dst", "db.sqlite"))
os.makedirs(SRC)
os.makedirs(DST)
COMMON = [f"file://{DST}", "--no-encryption", "--blocksize=10KB", "--dblock-size=100KB", f"--dbpath={DB}",
          "--console-log-level=Information"]


def cli(*args, kill=None):
    p = subprocess.Popen([CLI, args[0]] + COMMON + list(args[1:]), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        out, _ = p.communicate(timeout=kill)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        out, _ = p.communicate()
    lines = [l for l in out.splitlines() if l.strip() and not l.startswith("   at ")]
    return p.returncode, lines


def state():
    c = sqlite3.connect(DB)
    conf = dict(c.execute("SELECT Key, Value FROM Configuration WHERE Key IN ('repair-in-progress','partially-recreated')").fetchall())
    files = c.execute("SELECT COUNT(*) FROM FilesetEntry").fetchone()[0]
    sets = c.execute("SELECT COUNT(*) FROM Fileset").fetchone()[0]
    c.close()
    return conf, sets, files


for v in range(4):
    for i in range(250):
        with open(os.path.join(SRC, f"f{v}_{i}.bin"), "wb") as f:
            f.write(os.urandom(5000 + i * 300))
    cli("backup", SRC)
print("before recreate:", state())

os.remove(DB)
rc, lines = cli("repair", kill=DELAY)
print(f"recreate killed after {DELAY}s rc={rc}; state:", state())

rc, lines = cli("repair")
print("repair rc", rc)
for l in lines:
    if "Warning" in l or "in-progress" in l or "failed" in l or "blockset" in l:
        print("   ", l[:250])

rc, lines = cli("purge-broken-files", "--dry-run")
print("purge-broken-files --dry-run rc", rc)
for l in lines[:40]:
    print("   ", l[:250])

rc, lines = cli("purge-broken-files", "--dry-run", "--disable-replace-missing-metadata=true")
print("purge-broken-files --dry-run --disable-replace-missing-metadata rc", rc)
for l in lines:
    if any(k in l for k in ("Found", "Removing", "Purging", "Would", "fail", "Replacing", "broken", "Error")):
        print("   ", l[:250])
