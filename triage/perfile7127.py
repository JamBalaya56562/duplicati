"""Checks the plan of the lookup Duplicati runs once per file, under three sets of statistics.

Everything measured so far has been the query the forum thread names, and it is linear in
the folder count and never scans. But that query runs twice per backup. This one --

    SELECT "ID" FROM "FileLookup"
    WHERE "BlocksetID" = ? AND "MetadataID" = ? AND "Path" = ? AND "PrefixID" = ?

-- runs once for every file, from AddFileAsync. If the planner picks a table scan for it,
the backup becomes quadratic in the number of files, and that is a shape that reaches
hours where a linear one reaches seconds.

The three states are the ones a backup actually sees:

  none     the first backup, before any ANALYZE has run: sqlite assumes about a million
           rows per table and reaches for an index.
  stale    the second backup: PRAGMA optimize ran at the end of the first backup and wrote
           statistics describing a database with a handful of rows in it.
  current  statistics that fit the database as it is.

Run against SQLite 3.53.4, the version the product ships.
"""
import shutil
import sys
import time

import apsw

small_db, base_db, workdir = sys.argv[1], sys.argv[2], sys.argv[3]

QUERY = """
SELECT "ID"
FROM "FileLookup"
WHERE
    "BlocksetID" = ?
    AND "MetadataID" = ?
    AND "Path" = ?
    AND "PrefixID" = ?
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
    # "none" leaves the table empty, which is what a database that has never been
    # analyzed looks like to the planner.
    con.close()


def measure(path, label):
    con = apsw.Connection(path, flags=apsw.SQLITE_OPEN_READONLY)
    rows = list(con.execute(
        'SELECT "PrefixID", "Path", "BlocksetID", "MetadataID" FROM "FileLookup" '
        'WHERE "BlocksetID" >= 0 LIMIT 400'))
    plan = [r[-1] for r in con.execute(
        "EXPLAIN QUERY PLAN " + QUERY, (rows[0][2], rows[0][3], rows[0][1], rows[0][0]))]

    # Timed over many lookups, because one is too quick to separate a seek from a scan.
    start = time.perf_counter()
    for _ in range(25):
        for prefix, path_, blockset, meta in rows:
            list(con.execute(QUERY, (blockset, meta, path_, prefix)))
    secs = time.perf_counter() - start
    con.close()

    lookups = 25 * len(rows)
    print("   %-8s %8.3fs for %d lookups (%.3f ms each)   %s"
          % (label, secs, lookups, secs * 1000 / lookups, "; ".join(plan)))


print("sqlite:", apsw.sqlite_lib_version())
stale = stats_of(small_db)

work = "%s/perfile-work.sqlite" % workdir
shutil.copy(base_db, work)

con = apsw.Connection(work, flags=apsw.SQLITE_OPEN_READONLY)
print("FileLookup rows:", list(con.execute('SELECT COUNT(*) FROM "FileLookup"'))[0][0])
con.close()
print()

for kind in ("none", "stale", "current"):
    set_stats(work, kind, stale)
    measure(work, kind)
