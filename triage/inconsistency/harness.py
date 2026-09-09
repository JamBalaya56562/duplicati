#!/usr/bin/env python3
"""Tries to reach a "Found inconsistency" database state on a Duplicati build by
interrupting and disturbing operations. After every step, the database is checked
with the same queries as LocalDatabase.VerifyConsistencyInnerAsync."""
import os, sys, random, shutil, signal, sqlite3, subprocess, time, json, threading

CLI = os.path.expanduser(sys.argv[1])
WORK = os.path.expanduser(sys.argv[2])
SCENARIOS = sys.argv[3].split(",")
ITER = int(sys.argv[4]) if len(sys.argv) > 4 else 20
SEED = int(sys.argv[5]) if len(sys.argv) > 5 else 1
rnd = random.Random(SEED)

BLOCKSIZE = 10 * 1024
HASHSIZE = 32
COMMON = ["--no-encryption", f"--blocksize={BLOCKSIZE // 1024}KB", "--dblock-size=300KB",
          "--console-log-level=Warning", "--disable-module=console-password-input"]

findings = []


def log(*a):
    print(*a, flush=True)


def check(db, label):
    """Returns a list of problem strings (empty when consistent)"""
    if not os.path.exists(db):
        return []
    problems = []
    try:
        c = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
        rows = c.execute('''
            SELECT B.ID, IFNULL(SUM(K.Size),0) AS CalcLen, B.Length,
                   (SELECT GROUP_CONCAT(Path, ';') FROM File F WHERE F.BlocksetID = B.ID)
            FROM Blockset B LEFT JOIN BlocksetEntry E ON E.BlocksetID = B.ID
            LEFT JOIN Block K ON K.ID = E.BlockID
            GROUP BY B.ID HAVING IFNULL(SUM(K.Size),0) != B.Length''').fetchall()
        for r in rows:
            problems.append(f"LENGTH blockset={r[0]} calc={r[1]} len={r[2]} files={r[3]}")
        real = c.execute("SELECT COUNT(*) FROM BlocklistHash").fetchone()[0]
        uniq = c.execute("SELECT COUNT(*) FROM (SELECT DISTINCT BlocksetID, \"Index\" FROM BlocklistHash)").fetchone()[0]
        if real != uniq:
            problems.append(f"BLOCKLISTDUP real={real} unique={uniq}")
        per = BLOCKSIZE // HASHSIZE
        missing = c.execute(f'''
            SELECT COUNT(*) FROM (SELECT N.BlocksetID,
                ((N.BlockCount + {per} - 1) / {per}) AS Exp,
                (SELECT COUNT(*) FROM BlocklistHash H WHERE H.BlocksetID = N.BlocksetID) AS Act
              FROM (SELECT BlocksetID, COUNT(*) AS BlockCount FROM BlocksetEntry GROUP BY BlocksetID) N
              WHERE N.BlockCount > 1) WHERE Exp != Act''').fetchone()[0]
        if missing:
            problems.append(f"BLOCKLISTMISSING count={missing}")
        c.close()
    except sqlite3.Error as e:
        problems.append(f"SQLITE {e}")
    if problems:
        findings.append({"label": label, "problems": problems})
        log(f"  !!! {label}: {problems[:3]}")
    return problems


def run(args, name, kill_after=None, sig=signal.SIGKILL, env_extra=None):
    """Runs the CLI; optionally kills it. Returns (rc, output, killed)"""
    out = os.path.join(WORK, "logs", f"{name}.log")
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    with open(out, "w") as f:
        p = subprocess.Popen([CLI] + args, stdout=f, stderr=subprocess.STDOUT, start_new_session=True, env=env)
        killed = False
        if kill_after is not None:
            try:
                p.wait(timeout=kill_after)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(p.pid, sig)
                except ProcessLookupError:
                    pass
                killed = True
        try:
            rc = p.wait(timeout=600)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL)
            rc = p.wait()
        if killed and sig != signal.SIGKILL:
            # make sure nothing lingers
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    with open(out, errors="replace") as f:
        text = f.read()
    return rc, text, killed


def summary(text):
    for key in ["Found inconsistency", "DatabaseInconsistency", "Found ", "Fatal error", "Backup completed successfully",
                "Error", "Unexpected difference"]:
        for line in text.splitlines():
            if key in line:
                return line.strip()[:200]
    return text.strip().splitlines()[-1][:200] if text.strip() else ""


class Env:
    def __init__(self, name):
        self.root = os.path.join(WORK, name)
        shutil.rmtree(self.root, ignore_errors=True)
        os.makedirs(self.root)
        self.src = os.path.join(self.root, "src")
        self.dst = os.path.join(self.root, "dst")
        self.db = os.path.join(self.root, "db.sqlite")
        os.makedirs(self.src)
        os.makedirs(self.dst)
        self.url = "file://" + self.dst
        self.n = 0

    def opts(self, *extra):
        return [self.url] + list(extra) + COMMON + [f"--dbpath={self.db}"]

    def name(self, op):
        self.n += 1
        return f"{os.path.basename(self.root)}-{self.n:03d}-{op}"


def write_file(path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        # Mix of random and repeated content, so some blocks deduplicate
        remaining = size
        while remaining > 0:
            chunk = min(remaining, rnd.choice([BLOCKSIZE, BLOCKSIZE // 3, 4096, 65536]))
            if rnd.random() < 0.3:
                f.write(bytes([rnd.randrange(4)]) * chunk)
            else:
                f.write(os.urandom(chunk))
            remaining -= chunk


def populate(env, count=200):
    for i in range(count):
        size = rnd.choice([0, 1, BLOCKSIZE - 1, BLOCKSIZE, BLOCKSIZE + 1, rnd.randrange(1, 200_000),
                           rnd.randrange(1, 40_000), BLOCKSIZE * 320, BLOCKSIZE * 321 + 7])
        write_file(os.path.join(env.src, f"d{i % 7}", f"f{i}.bin"), size)


def churn(env, frac=0.15):
    files = [os.path.join(dp, f) for dp, _, fs in os.walk(env.src) for f in fs]
    for p in rnd.sample(files, max(1, int(len(files) * frac))):
        r = rnd.random()
        if r < 0.3:
            os.remove(p)
        elif r < 0.6:
            write_file(p, rnd.randrange(0, 150_000))
        else:
            with open(p, "ab") as f:
                f.write(os.urandom(rnd.randrange(1, 30_000)))
    for i in range(rnd.randrange(1, 15)):
        write_file(os.path.join(env.src, "new", f"n{time.time_ns()}_{i}.bin"), rnd.randrange(0, 120_000))


def backup(env, label, **kw):
    rc, text, killed = run(["backup"] + env.opts(env.src), env.name(label), **kw)
    return rc, text, killed


def baseline_timing(env):
    t = time.time()
    rc, text, _ = backup(env, "timing")
    return time.time() - t, rc, text


# ---------------------------------------------------------------- scenarios

def sc_kill_backup(sig=signal.SIGKILL, tag="kill-backup"):
    env = Env(tag)
    populate(env)
    dur, rc, text = baseline_timing(env)
    log(f"[{tag}] first backup rc={rc} {dur:.1f}s {summary(text)}")
    check(env.db, f"{tag} initial")
    for i in range(ITER):
        churn(env)
        delay = rnd.uniform(0.2, 4.0)
        rc, text, killed = backup(env, f"backup-k{i}", kill_after=delay, sig=sig)
        p1 = check(env.db, f"{tag} it{i} after kill@{delay:.2f}s killed={killed}")
        rc2, text2, _ = backup(env, f"backup-after{i}")
        p2 = check(env.db, f"{tag} it{i} after follow-up backup")
        log(f"[{tag}] it{i} kill@{delay:.2f}s killed={killed} rc={rc} -> next rc={rc2} {summary(text2)}")
        if rc2 != 0 and "inconsisten" in text2.lower():
            findings.append({"label": f"{tag} it{i} follow-up", "problems": [summary(text2)]})
    final_check(env, tag)


def sc_sigint_backup():
    sc_kill_backup(signal.SIGINT, "sigint-backup")


def sc_mutate_during_backup():
    env = Env("mutate")
    populate(env, 120)
    for i in range(6):
        write_file(os.path.join(env.src, "big", f"big{i}.bin"), 3_000_000)
    backup(env, "first")
    check(env.db, "mutate initial")
    for i in range(ITER):
        stop = threading.Event()

        def mutator():
            files = [os.path.join(dp, f) for dp, _, fs in os.walk(env.src) for f in fs]
            while not stop.is_set():
                p = rnd.choice(files)
                try:
                    r = rnd.random()
                    if r < 0.25:
                        with open(p, "r+b") as f:
                            f.truncate(rnd.randrange(0, max(1, os.path.getsize(p))))
                    elif r < 0.5:
                        with open(p, "ab") as f:
                            f.write(os.urandom(rnd.randrange(1, 50_000)))
                    elif r < 0.7:
                        with open(p, "r+b") as f:
                            f.seek(rnd.randrange(0, max(1, os.path.getsize(p))))
                            f.write(os.urandom(rnd.randrange(1, 20_000)))
                    elif r < 0.8:
                        os.remove(p)
                        write_file(p, rnd.randrange(0, 200_000))
                    else:
                        write_file(p, rnd.randrange(0, 3_000_000))
                except OSError:
                    pass
                time.sleep(rnd.uniform(0, 0.01))

        t = threading.Thread(target=mutator)
        t.start()
        rc, text, _ = backup(env, f"backup-m{i}")
        stop.set()
        t.join()
        check(env.db, f"mutate it{i} rc={rc}")
        rc2, text2, _ = backup(env, f"backup-after{i}")
        check(env.db, f"mutate it{i} follow-up")
        log(f"[mutate] it{i} rc={rc} {summary(text)} -> next rc={rc2} {summary(text2)}")
    final_check(env, "mutate")


def make_versions(env, n):
    for i in range(n):
        churn(env, 0.3)
        backup(env, f"v{i}")


def sc_kill_compact():
    env = Env("kill-compact")
    populate(env, 150)
    for i in range(ITER):
        make_versions(env, 3)
        run(["delete"] + env.opts("--keep-versions=1", "--no-auto-compact"), env.name("delete"))
        check(env.db, f"compact it{i} after delete")
        t = time.time()
        delay = rnd.uniform(0.2, 4.0)
        rc, text, killed = run(["compact"] + env.opts("--threshold=5", "--small-file-size=200KB", "--small-file-max-count=2"),
                               env.name(f"compact-k{i}"), kill_after=delay)
        check(env.db, f"compact it{i} after kill@{delay:.2f}s killed={killed}")
        rc2, text2, _ = run(["compact"] + env.opts("--threshold=5"), env.name("compact-after"))
        check(env.db, f"compact it{i} after follow-up compact")
        rc3, text3, _ = backup(env, f"backup-after{i}")
        check(env.db, f"compact it{i} after backup")
        log(f"[kill-compact] it{i} kill@{delay:.2f}s killed={killed} rc={rc} compact2 rc={rc2} {summary(text2)} backup rc={rc3} {summary(text3)}")
    final_check(env, "kill-compact")


def sc_kill_delete():
    env = Env("kill-delete")
    populate(env, 150)
    for i in range(ITER):
        make_versions(env, 3)
        delay = rnd.uniform(0.2, 3.0)
        rc, text, killed = run(["delete"] + env.opts("--keep-versions=1", "--threshold=5"), env.name(f"delete-k{i}"), kill_after=delay)
        check(env.db, f"delete it{i} after kill@{delay:.2f}s killed={killed}")
        rc2, text2, _ = backup(env, f"backup-after{i}")
        check(env.db, f"delete it{i} after backup")
        log(f"[kill-delete] it{i} kill@{delay:.2f}s killed={killed} rc={rc} backup rc={rc2} {summary(text2)}")
    final_check(env, "kill-delete")


def sc_kill_recreate():
    env = Env("kill-recreate")
    populate(env, 150)
    make_versions(env, 4)
    for i in range(ITER):
        if os.path.exists(env.db):
            os.remove(env.db)
        delay = rnd.uniform(0.3, 6.0)
        rc, text, killed = run(["repair"] + env.opts(), env.name(f"recreate-k{i}"), kill_after=delay)
        check(env.db, f"recreate it{i} after kill@{delay:.2f}s killed={killed}")
        rc2, text2, _ = run(["repair"] + env.opts(), env.name(f"repair-after{i}"))
        check(env.db, f"recreate it{i} after repair")
        rc3, text3, _ = backup(env, f"backup-after{i}")
        check(env.db, f"recreate it{i} after backup")
        log(f"[kill-recreate] it{i} kill@{delay:.2f}s killed={killed} rc={rc} repair rc={rc2} {summary(text2)} backup rc={rc3} {summary(text3)}")


def remote_files(env, kind):
    return sorted(f for f in os.listdir(env.dst) if f".{kind}." in f)


def sc_remote_damage():
    env = Env("remote-damage")
    populate(env, 150)
    make_versions(env, 4)
    actions = ["del-dblock", "del-dindex", "del-dlist", "trunc-dblock", "corrupt-dblock", "del-dblock+dindex"]
    for i in range(ITER):
        action = actions[i % len(actions)]
        blocks = remote_files(env, "dblock")
        indexes = remote_files(env, "dindex")
        lists = remote_files(env, "dlist")
        try:
            if action == "del-dblock" and blocks:
                os.remove(os.path.join(env.dst, rnd.choice(blocks)))
            elif action == "del-dindex" and indexes:
                os.remove(os.path.join(env.dst, rnd.choice(indexes)))
            elif action == "del-dlist" and len(lists) > 1:
                os.remove(os.path.join(env.dst, rnd.choice(lists)))
            elif action == "trunc-dblock" and blocks:
                p = os.path.join(env.dst, rnd.choice(blocks))
                with open(p, "r+b") as f:
                    f.truncate(os.path.getsize(p) // 2)
            elif action == "corrupt-dblock" and blocks:
                p = os.path.join(env.dst, rnd.choice(blocks))
                with open(p, "r+b") as f:
                    f.seek(os.path.getsize(p) // 2)
                    f.write(os.urandom(64))
            elif action == "del-dblock+dindex" and blocks and indexes:
                os.remove(os.path.join(env.dst, rnd.choice(blocks)))
                os.remove(os.path.join(env.dst, rnd.choice(indexes)))
        except OSError:
            pass
        steps = []
        for op, args in [("repair", ["repair"] + env.opts()),
                         ("purge-broken", ["purge-broken-files"] + env.opts()),
                         ("repair2", ["repair"] + env.opts()),
                         ("test", ["test"] + env.opts("all", "--full-remote-verification=true")),
                         ("backup", ["backup"] + env.opts(env.src))]:
            rc, text, _ = run(args, env.name(op))
            check(env.db, f"remote-damage it{i} {action} after {op}")
            steps.append(f"{op}={rc}")
        log(f"[remote-damage] it{i} {action}: {' '.join(steps)}")
        churn(env)
        backup(env, "churn")


def sc_kill_repair():
    env = Env("kill-repair")
    populate(env, 150)
    make_versions(env, 3)
    for i in range(ITER):
        blocks = remote_files(env, "dblock")
        indexes = remote_files(env, "dindex")
        if i % 2 == 0 and indexes:
            os.remove(os.path.join(env.dst, rnd.choice(indexes)))
        elif blocks:
            os.remove(os.path.join(env.dst, rnd.choice(blocks)))
        delay = rnd.uniform(0.2, 4.0)
        rc, text, killed = run(["repair"] + env.opts(), env.name(f"repair-k{i}"), kill_after=delay)
        check(env.db, f"kill-repair it{i} after kill@{delay:.2f}s killed={killed}")
        for op, args in [("repair", ["repair"] + env.opts()), ("purge-broken", ["purge-broken-files"] + env.opts()),
                         ("backup", ["backup"] + env.opts(env.src))]:
            rcx, textx, _ = run(args, env.name(op))
            check(env.db, f"kill-repair it{i} after {op}")
        log(f"[kill-repair] it{i} kill@{delay:.2f}s killed={killed} rc={rc} last={rcx} {summary(textx)}")
        churn(env)


def sc_kill_purge():
    env = Env("kill-purge")
    populate(env, 150)
    make_versions(env, 3)
    for i in range(ITER):
        delay = rnd.uniform(0.2, 3.0)
        rc, text, killed = run(["purge"] + env.opts(f"*/d{i % 7}/f{rnd.randrange(150)}.bin", f"*/new/*"), env.name(f"purge-k{i}"), kill_after=delay)
        check(env.db, f"kill-purge it{i} after kill@{delay:.2f}s killed={killed}")
        rc2, text2, _ = backup(env, f"backup-after{i}")
        check(env.db, f"kill-purge it{i} after backup")
        log(f"[kill-purge] it{i} kill@{delay:.2f}s killed={killed} rc={rc} backup rc={rc2} {summary(text2)}")
        churn(env)
    backup(env, "final")
    final_check(env, "kill-purge")


def sc_backend_errors():
    """Destination becomes read-only / disappears in the middle of a backup"""
    env = Env("backend-errors")
    populate(env, 150)
    backup(env, "first")
    for i in range(ITER):
        churn(env, 0.3)
        delay = rnd.uniform(0.1, 2.0)

        def breaker():
            time.sleep(delay)
            if i % 2 == 0:
                os.chmod(env.dst, 0o555)
            else:
                os.rename(env.dst, env.dst + ".gone")

        t = threading.Thread(target=breaker)
        t.start()
        rc, text, _ = backup(env, f"backup-e{i}", env_extra=None)
        t.join()
        if os.path.exists(env.dst + ".gone"):
            # Like a drive that comes back: what was written to the folder created in its place is lost
            recreated = os.listdir(env.dst) if os.path.exists(env.dst) else []
            if recreated:
                log(f"  it{i}: {len(recreated)} file(s) written to the recreated folder are discarded")
            shutil.rmtree(env.dst, ignore_errors=True)
            os.rename(env.dst + ".gone", env.dst)
        os.chmod(env.dst, 0o755)
        check(env.db, f"backend-errors it{i} after failing backup")
        rc2, text2, _ = backup(env, f"backup-after{i}")
        check(env.db, f"backend-errors it{i} after backup")
        if rc2 != 0:
            rc3, text3, _ = run(["repair"] + env.opts(), env.name("repair"))
            check(env.db, f"backend-errors it{i} after repair")
            rc2, text2, _ = backup(env, f"backup-after-repair{i}")
            check(env.db, f"backend-errors it{i} after backup2")
        log(f"[backend-errors] it{i} break@{delay:.2f}s rc={rc} {summary(text)} -> rc={rc2} {summary(text2)}")
    final_check(env, "backend-errors")


def final_check(env, tag):
    """Tests every volume, and restores the latest version to compare it with the source"""
    rc, text, _ = run(["test"] + env.opts("all", "--full-remote-verification=true"), env.name("final-test"))
    out = os.path.join(env.root, "restored")
    shutil.rmtree(out, ignore_errors=True)
    rc2, text2, _ = run(["restore"] + env.opts("*", f"--restore-path={out}"), env.name("final-restore"))
    differ = []
    for dp, _, fs in os.walk(env.src):
        for f in fs:
            a = os.path.join(dp, f)
            b = os.path.join(out, os.path.relpath(a, env.src))
            if not os.path.exists(b) or open(a, "rb").read() != open(b, "rb").read():
                differ.append(os.path.relpath(a, env.src))
    log(f"[{tag}] final test rc={rc} {summary(text)} | restore rc={rc2} {summary(text2)} | differing files: {len(differ)} {differ[:5]}")
    if rc != 0 or rc2 not in (0, 1) or differ:
        findings.append({"label": f"{tag} final", "problems": [f"test rc={rc}", f"restore rc={rc2}", f"differ={differ[:5]}"]})


def write_sparse(path, size, holes=True):
    """A file of mostly identical blocks (zeros), with a few unique ones"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.truncate(size)
        for _ in range(rnd.randrange(0, 6)):
            f.seek(rnd.randrange(0, max(1, size - 100)))
            f.write(os.urandom(rnd.randrange(1, 3 * BLOCKSIZE)))
    if not holes:
        return


def recreate_and_check(env, label):
    """Recreates the database from the remote, then checks it and runs a backup"""
    saved = env.db + ".before"
    if os.path.exists(env.db):
        shutil.copy(env.db, saved)
        os.remove(env.db)
    rc, text, _ = run(["repair"] + env.opts(), env.name(f"recreate-{label}"))
    p = check(env.db, f"{env.root} {label} after recreate rc={rc}")
    rc2, text2, _ = backup(env, f"backup-{label}")
    p2 = check(env.db, f"{env.root} {label} after backup")
    rc3, text3, _ = run(["test"] + env.opts("all"), env.name(f"test-{label}"))
    log(f"  {label}: recreate rc={rc} {summary(text)} | backup rc={rc2} {summary(text2)} | test rc={rc3} {summary(text3)} | problems={len(p)}/{len(p2)}")
    return rc, rc2, rc3


def sc_recreate_variants():
    env = Env("recreate-variants")
    populate(env, 80)
    # Sparse and repeated-content files, including ones longer than one blocklist (320 blocks)
    for i, blocks in enumerate([1, 2, 319, 320, 321, 641, 1000]):
        write_sparse(os.path.join(env.src, "sparse", f"s{i}.bin"), blocks * BLOCKSIZE + rnd.choice([0, 1, 777]))
    with open(os.path.join(env.src, "sparse", "allsame.bin"), "wb") as f:
        f.write(b"A" * (BLOCKSIZE * 700))
    for i in range(5):
        shutil.copy(os.path.join(env.src, "sparse", "s3.bin"), os.path.join(env.src, "sparse", f"copy{i}.bin"))
    for i in range(10):
        open(os.path.join(env.src, "sparse", f"empty{i}"), "wb").close()
    backup(env, "first")
    check(env.db, "recreate-variants first")
    recreate_and_check(env, "r0-plain")
    for i in range(ITER):
        step = i % 5
        churn(env, 0.2)
        if step == 0:
            # sparse files change in place
            for p in rnd.sample([os.path.join(env.src, "sparse", f) for f in os.listdir(os.path.join(env.src, "sparse"))], 4):
                write_sparse(p, rnd.randrange(0, 1100) * BLOCKSIZE + rnd.choice([0, 3]))
            backup(env, f"b{i}")
        elif step == 1:
            # interrupted backup, then a normal one
            backup(env, f"bk{i}", kill_after=rnd.uniform(0.3, 2.5))
            backup(env, f"b{i}")
        elif step == 2:
            backup(env, f"b{i}")
            run(["delete"] + env.opts("--keep-versions=2", "--no-auto-compact"), env.name("delete"))
            run(["compact"] + env.opts("--threshold=1", "--small-file-max-count=1"), env.name("compact"))
        elif step == 3:
            backup(env, f"b{i}", kill_after=None)
            run(["purge"] + env.opts("*/sparse/copy1.bin"), env.name("purge"))
        else:
            backup(env, f"bk{i}", kill_after=rnd.uniform(0.3, 2.5))
            run(["compact"] + env.opts("--threshold=1"), env.name("compact"), kill_after=rnd.uniform(0.5, 3))
            backup(env, f"b{i}")
        check(env.db, f"recreate-variants it{i} before recreate")
        recreate_and_check(env, f"it{i}-step{step}")


SC = {
    "recreate-variants": sc_recreate_variants,
    "kill-backup": sc_kill_backup,
    "sigint-backup": sc_sigint_backup,
    "mutate": sc_mutate_during_backup,
    "kill-compact": sc_kill_compact,
    "kill-delete": sc_kill_delete,
    "kill-recreate": sc_kill_recreate,
    "remote-damage": sc_remote_damage,
    "kill-repair": sc_kill_repair,
    "kill-purge": sc_kill_purge,
    "backend-errors": sc_backend_errors,
}

os.makedirs(os.path.join(WORK, "logs"), exist_ok=True)
for s in SCENARIOS:
    t = time.time()
    try:
        SC[s]()
    except Exception as e:
        log(f"[{s}] harness error: {e!r}")
    log(f"[{s}] done in {time.time() - t:.0f}s, findings so far: {len(findings)}")

with open(os.path.join(WORK, f"findings-{'_'.join(SCENARIOS)}-{SEED}.json"), "w") as f:
    json.dump(findings, f, indent=1)
log(f"TOTAL findings: {len(findings)}")
for x in findings:
    log(json.dumps(x))
