"""Checks the metadata lookup Duplicati runs once per file, under three sets of statistics.

The reported cost grows with the number of files already processed -- the thread's time
per file climbs ninety-three-fold between 110 files and 1,110 -- so what is wanted is a
per-file query whose plan walks a table that grows as the backup proceeds. This one, from
AddMetadatasetAsync, is the best-shaped candidate left:

    SELECT "A"."ID"
    FROM "Metadataset" "A", "BlocksetEntry" "B", "Block" "C"
    WHERE "A"."BlocksetID" = "B"."BlocksetID"
      AND "B"."BlockID" = "C"."ID"
      AND "C"."Hash" = ? AND "C"."Size" = ?

Three tables joined with no join order forced, run once for every file, and the statistics
the second backup plans with say Metadataset holds four rows and BlocksetEntry five. If
that makes the planner drive from Metadataset, every file scans every metadata set written
so far, which is the quadratic shape being hunted.

Statistics states, as a backup meets them: none (the first backup, nothing analyzed yet),
stale (the second backup, PRAGMA optimize having described a one-file database) and
current. SQLite 3.53.4, the version the product ships.
"""
import shutil
import sys
import time

import apsw

small_db, base_db, workdir = sys.argv[1], sys.argv[2], sys.argv[3]

QUERY = """
SELECT "A"."ID"
FROM
    "Metadataset" "A",
    "BlocksetEntry" "B",
    "Block" "C"
WHERE
    "A"."BlocksetID" = "B"."BlocksetID"
    AND "B"."BlockID" = "C"."ID"
    AND "C"."Hash" = ?
    AND "C"."Size" = ?
"""


def stats_of(path):
    con = apsw.Connection(path, flags=apsw.SQLITE_OPEN_READONLY)
    try:
        return list(con.execute("SELECT tbl, idx, stat FROM sqlite_stat1"))
    except apsw.SQLError:
        return []
    finally:
        con.close()


def set_stats(path, kind, stale):
    con = apsw.Connection(path)
    con.execute("DELETE FROM sqlite_stat1")
    if kind == "current":
        con.execute("ANALYZE")
    elif kind == "stale":
        con.executemany("INSERT INTO sqlite_stat1 (tbl, idx, stat) VALUES (?, ?, ?)", stale)
    con.close()


def measure(path, label, samples):
    con = apsw.Connection(path, flags=apsw.SQLITE_OPEN_READONLY)
    plan = [r[-1] for r in con.execute("EXPLAIN QUERY PLAN " + QUERY, samples[0])]
    scans = [p for p in plan if p.startswith("SCAN")]

    start = time.perf_counter()
    for h, size in samples:
        list(con.execute(QUERY, (h, size)))
    secs = time.perf_counter() - start
    con.close()

    print("   %-8s %8.3fs for %4d lookups (%7.3f ms each)%s"
          % (label, secs, len(samples), secs * 1000 / len(samples),
             "   SCAN: " + "; ".join(scans) if scans else ""))
    for line in plan:
        print("            %s" % line)


print("sqlite:", apsw.sqlite_lib_version())
stale = stats_of(small_db)

work = "%s/metaset-work.sqlite" % workdir
shutil.copy(base_db, work)

con = apsw.Connection(work, flags=apsw.SQLITE_OPEN_READONLY)
print("Metadataset rows:", list(con.execute('SELECT COUNT(*) FROM "Metadataset"'))[0][0])
print("BlocksetEntry rows:", list(con.execute('SELECT COUNT(*) FROM "BlocksetEntry"'))[0][0])
samples = [(h, s) for h, s in con.execute('SELECT "Hash", "Size" FROM "Block" LIMIT 300')]
con.close()
print()

for kind in ("none", "stale", "current"):
    set_stats(work, kind, stale)
    measure(work, kind, samples)
    print()
