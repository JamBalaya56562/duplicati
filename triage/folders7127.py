"""Measures how LIST_FOLDERS_AND_SYMLINKS grows with the number of folders.

The forum thread's figures for the second backup are 0.171s at 10 folders, 10.180s at 44,
81.810s at 88 and 159.780s at 110: doubling the folders multiplies the time by eight, so
the cost goes as the cube of the folder count. Nothing measured here so far grows like
that, so this puts the question directly -- clone folders into a real database until there
are ten thousand of them and time the query at each size.

A folder is cloned the way a backup writes one: its own metadata blockset, holding one
block, with a Metadataset row pointing at it and a FileLookup row whose BlocksetID is the
folder marker. Each folder therefore has metadata of its own, which is what the real
database looks like, since folders differ in their timestamps.

Run against the planner the product ships (SQLite 3.53.4 via apsw), under both the
statistics the second backup plans with and statistics that fit the grown database.
"""
import shutil
import sys
import time

import apsw

source, small_db, base_db, workdir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
BUDGET = 300.0
FOLDER_BLOCKSET_ID = -100


def extract(name):
    text = open(source, encoding="utf-8-sig").read()
    start = text.index('@"', text.index('public const string %s = @"' % name)) + 2
    i = start
    while True:
        i = text.index('"', i)
        if text[i:i + 2] == '""':
            i += 2
            continue
        break
    return text[start:i].replace('""', '"')


def prepare(sql, fileset):
    return (sql.replace("@FilesetId", str(fileset))
               .replace("@FolderBlocksetId", str(FOLDER_BLOCKSET_ID))
               .replace("@SymlinkBlocksetId", "-200"))


def add_folders(path, fileset, wanted):
    """Clones folders until the fileset holds `wanted` of them."""
    con = apsw.Connection(path)
    have = list(con.execute(
        'SELECT COUNT(*) FROM "FilesetEntry" A JOIN "FileLookup" B ON A."FileID"=B."ID" '
        'WHERE B."BlocksetID" IN (-100,-200) AND A."FilesetID"=?', (fileset,)))[0][0]
    if have >= wanted:
        con.close()
        return have

    prefix_id = list(con.execute('SELECT "ID" FROM "PathPrefix" LIMIT 1'))[0][0]
    volume_id = list(con.execute('SELECT "VolumeID" FROM "Block" LIMIT 1'))[0][0]
    next_block = list(con.execute('SELECT MAX("ID") FROM "Block"'))[0][0] + 1
    next_blockset = list(con.execute('SELECT MAX("ID") FROM "Blockset"'))[0][0] + 1
    next_meta = list(con.execute('SELECT MAX("ID") FROM "Metadataset"'))[0][0] + 1
    next_file = list(con.execute('SELECT MAX("ID") FROM "FileLookup"'))[0][0] + 1

    n = wanted - have
    con.execute("BEGIN")
    con.executemany('INSERT INTO "Block" ("ID","Hash","Size","VolumeID") VALUES (?,?,?,?)',
                    ((next_block + i, "synthetic-meta-block-%d" % (next_block + i), 137, volume_id) for i in range(n)))
    con.executemany('INSERT INTO "Blockset" ("ID","Length","FullHash") VALUES (?,?,?)',
                    ((next_blockset + i, 137, "synthetic-meta-blockset-%d" % (next_blockset + i)) for i in range(n)))
    con.executemany('INSERT INTO "BlocksetEntry" ("BlocksetID","Index","BlockID") VALUES (?,0,?)',
                    ((next_blockset + i, next_block + i) for i in range(n)))
    con.executemany('INSERT INTO "Metadataset" ("ID","BlocksetID") VALUES (?,?)',
                    ((next_meta + i, next_blockset + i) for i in range(n)))
    con.executemany('INSERT INTO "FileLookup" ("ID","PrefixID","Path","BlocksetID","MetadataID") '
                    'VALUES (?,?,?,?,?)',
                    ((next_file + i, prefix_id, "synthetic-folder-%08d" % (next_file + i), FOLDER_BLOCKSET_ID,
                      next_meta + i) for i in range(n)))
    con.executemany('INSERT INTO "FilesetEntry" ("FilesetID","FileID","Lastmodified") VALUES (?,?,0)',
                    ((fileset, next_file + i) for i in range(n)))
    con.execute("COMMIT")
    con.close()
    return wanted


def stats_of(path):
    con = apsw.Connection(path, flags=apsw.SQLITE_OPEN_READONLY)
    try:
        return list(con.execute("SELECT tbl, idx, stat FROM sqlite_stat1"))
    except apsw.SQLError:
        return []
    finally:
        con.close()


def with_stats(path, stats):
    con = apsw.Connection(path)
    if stats is None:
        con.execute("ANALYZE")
    else:
        con.execute("DELETE FROM sqlite_stat1")
        con.executemany("INSERT INTO sqlite_stat1 (tbl, idx, stat) VALUES (?, ?, ?)", stats)
    con.close()


def run(path, sql, label):
    con = apsw.Connection(path, flags=apsw.SQLITE_OPEN_READONLY)
    plan = [r[-1] for r in con.execute("EXPLAIN QUERY PLAN " + sql)]
    scans = [p for p in plan if p.startswith("SCAN")]

    deadline = time.perf_counter() + BUDGET
    con.set_progress_handler(lambda: time.perf_counter() > deadline, 20000)
    start = time.perf_counter()
    try:
        rows = sum(1 for _ in con.execute(sql))
        outcome = "%8.3fs %7d rows" % (time.perf_counter() - start, rows)
    except Exception:
        outcome = "ABORTED past %.0fs" % (time.perf_counter() - start)
    finally:
        con.close()
    print("   %-8s %s   driver: %s%s"
          % (label, outcome, plan[0] if plan else "(none)",
             ("   SCANS: " + "; ".join(scans)) if scans else ""))


print("sqlite:", apsw.sqlite_lib_version())
small = stats_of(small_db)

con = apsw.Connection(base_db, flags=apsw.SQLITE_OPEN_READONLY)
fileset = list(con.execute('SELECT MAX("ID") FROM "Fileset"'))[0][0]
con.close()
sql = prepare(extract("LIST_FOLDERS_AND_SYMLINKS"), fileset)

work = "%s/folders-work.sqlite" % workdir
shutil.copy(base_db, work)

for wanted in (111, 400, 1110, 4000, 11100):
    have = add_folders(work, fileset, wanted)
    print()
    print("=== %d folders ===" % have)
    with_stats(work, None)
    run(work, sql, "current")
    with_stats(work, small)
    run(work, sql, "stale")
