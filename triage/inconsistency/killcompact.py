#!/usr/bin/env python3
"""Kills compact at random points, then runs compact again and a test.
usage: killcompact.py <cli> <workdir> <iterations> <seed>"""
import os, sys, shutil, subprocess, random, time

CLI, WORK, ITER, SEED = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
rnd = random.Random(SEED)
shutil.rmtree(WORK, ignore_errors=True)
SRC, DST, DB = (os.path.join(WORK, x) for x in ("src", "dst", "db.sqlite"))
os.makedirs(SRC)
os.makedirs(DST)
COMMON = [f"file://{DST}", "--no-encryption", "--blocksize=10KB", "--dblock-size=300KB", f"--dbpath={DB}",
          "--console-log-level=Warning", "--no-auto-compact=true"]


def cli(*args, kill=None):
    p = subprocess.Popen([CLI, args[0]] + COMMON + list(args[1:]), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    killed = False
    try:
        out, _ = p.communicate(timeout=kill)
    except subprocess.TimeoutExpired:
        p.kill()
        killed = True
        out, _ = p.communicate()
    return p.returncode, out, killed


def churn():
    for i in range(150):
        if rnd.random() < 0.4:
            with open(os.path.join(SRC, f"f{i}.bin"), "wb") as f:
                f.write(os.urandom(rnd.randrange(1000, 60000)))


counts = {"killed": 0, "compact2_fail": 0, "test_fail": 0, "backup_fail": 0}
churn()
cli("backup", SRC)
for it in range(ITER):
    for _ in range(3):
        churn()
        cli("backup", SRC)
    cli("delete", "--keep-versions=1")
    delay = rnd.uniform(0.3, 3.5)
    rc, out, killed = cli("compact", "--threshold=5", "--small-file-size=200KB", "--small-file-max-count=2", kill=delay)
    counts["killed"] += killed
    rc2, out2, _ = cli("compact", "--threshold=5")
    if rc2 != 0:
        counts["compact2_fail"] += 1
        line = next((l for l in out2.splitlines() if "failed" in l), out2.strip().splitlines()[-1])
        print(f"it{it} kill@{delay:.2f}s killed={killed}: compact rc={rc2} {line[:200]}", flush=True)
    rc3, out3, _ = cli("test", "all")
    if rc3 != 0:
        counts["test_fail"] += 1
        print(f"it{it}: test rc={rc3} {out3.strip().splitlines()[-1][:200]}", flush=True)
        with open(os.path.join(WORK, f"test-fail-it{it}.log"), "w") as f:
            f.write("\n".join([f"kill@{delay:.2f}s killed={killed}", "--- killed compact ---", out, "--- compact ---", out2, "--- test ---", out3]))
        shutil.copytree(DST, os.path.join(WORK, f"dst-it{it}"))
        shutil.copy(DB, os.path.join(WORK, f"db-it{it}.sqlite"))
    rc4, out4, _ = cli("backup", SRC)
    if rc4 not in (0, 1):
        counts["backup_fail"] += 1
        print(f"it{it}: backup rc={rc4} {out4.strip().splitlines()[-1][:200]}", flush=True)
print("RESULT", counts, flush=True)
