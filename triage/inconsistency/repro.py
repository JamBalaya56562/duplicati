#!/usr/bin/env python3
"""Minimal reproduction: purge-broken-files fails on a timestamp collision after it has
already dropped the missing blocks, leaving a database that fails with "Found inconsistency".
usage: repro.py <cli> <workdir>"""
import os, sys, shutil, subprocess, sqlite3, datetime

CLI, WORK = sys.argv[1], sys.argv[2]
shutil.rmtree(WORK, ignore_errors=True)
SRC, DST, DB = (os.path.join(WORK, x) for x in ("src", "dst", "db.sqlite"))
os.makedirs(SRC)
os.makedirs(DST)
COMMON = [f"file://{DST}", "--no-encryption", "--blocksize=10KB", "--dblock-size=100KB", f"--dbpath={DB}",
          "--console-log-level=Warning", "--no-auto-compact=true"]


def cli(*args):
    p = subprocess.run([CLI, args[0]] + COMMON + list(args[1:]), capture_output=True, text=True)
    lines = [l for l in (p.stdout + p.stderr).splitlines() if l.strip() and not l.startswith("   at ")]
    key = next((l for l in lines if "failed" in l or "inconsistency" in l or "completed" in l.lower()), lines[-1] if lines else "")
    print(f"$ {args[0]} {' '.join(args[1:])}\n  rc={p.returncode} {key[:300]}")
    return p.returncode, p.stdout + p.stderr


def filesets():
    c = sqlite3.connect(DB)
    r = [datetime.datetime.fromtimestamp(t, datetime.timezone.utc).strftime("%H:%M:%S")
         for (t,) in c.execute("SELECT Timestamp FROM Fileset ORDER BY Timestamp")]
    c.close()
    return r


def write(name, size):
    with open(os.path.join(SRC, name), "wb") as f:
        f.write(os.urandom(size))


# Version A: a large file spread over several block volumes, plus dummies that only A has
write("big.bin", 600_000)
write("small.bin", 1_000)
for i in range(10):
    write(f"dummy{i}.bin", 100)
cli("backup", SRC)
# Version B, right after: the dummies are gone, so purging one of them rewrites only A
for i in range(10):
    os.remove(os.path.join(SRC, f"dummy{i}.bin"))
write("small.bin", 1_001)
cli("backup", SRC)
print("filesets:", filesets())

# Each purge rewrites version A one second later, until it runs into version B
for i in range(10):
    rc, _ = cli("purge", f"*dummy{i}.bin", "--version=1")
    print("filesets:", filesets())
    if rc != 0:
        break

# A block volume goes missing; both versions hold big.bin, small.bin is intact
vols = sorted(f for f in os.listdir(DST) if ".dblock." in f)
victim = vols[len(vols) // 2]
os.remove(os.path.join(DST, victim))
print("removed", victim)

cli("purge-broken-files")
cli("backup", SRC)
cli("repair")
cli("purge-broken-files")
