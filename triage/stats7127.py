"""Compares query plans under the statistics left by a first backup with and without the
trigger file.

The thread reports that the problem stops happening when the one-byte file is left out of
the source, and the standing explanation is that the first backup's `PRAGMA optimize`
writes statistics that mislead the planner. If that were the mechanism, leaving the file
out would have to change those statistics into something harmless.

It does not: both runs leave a full set of statistics describing a database of a handful
of rows, five with the file and three without. This checks whether that difference reaches
the plans at all.

SQLite 3.53.4, the version the product ships.
"""
import shutil
import sys

import apsw

source, trigger_db, notrigger_db, base_db, workdir = sys.argv[1:6]

QUERIES = {
    "find fileset (per file)": ("""
        SELECT "ID" FROM "FileLookup"
        WHERE "BlocksetID" = 0 AND "MetadataID" = 0 AND "Path" = 'x' AND "PrefixID" = 1
    """, None),
    "find metadataset (per file)": ("""
        SELECT "A"."ID"
        FROM "Metadataset" "A", "BlocksetEntry" "B", "Block" "C"
        WHERE "A"."BlocksetID" = "B"."BlocksetID" AND "B"."BlockID" = "C"."ID"
          AND "C"."Hash" = 'x' AND "C"."Size" = 0
    """, None),
    "find block (per block)": ("""
        SELECT "ID" FROM "Block" WHERE "Hash" = 'x' AND "Size" = 0
    """, None),
    "find blockset (per file)": ("""
        SELECT "ID" FROM "Blockset" WHERE "Fullhash" = 'x' AND "Length" = 0
    """, None),
    "select last modified (per file)": ("""
        SELECT "A"."ID", "B"."LastModified"
        FROM (SELECT "ID" FROM "FileLookup" WHERE "PrefixID" = 1 AND "Path" = 'x') "A"
        CROSS JOIN "FilesetEntry" "B"
        WHERE "A"."ID" = "B"."FileID" AND "B"."FilesetID" = 2
    """, None),
    "LIST_FOLDERS_AND_SYMLINKS": (None, "LIST_FOLDERS_AND_SYMLINKS"),
    "LIST_FILESETS": (None, "LIST_FILESETS"),
}


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
    return (text[start:i].replace('""', '"')
            .replace("@FilesetId", "2").replace("@FolderBlocksetId", "-100")
            .replace("@SymlinkBlocksetId", "-200"))


def stats_of(path):
    con = apsw.Connection(path, flags=apsw.SQLITE_OPEN_READONLY)
    try:
        return list(con.execute("SELECT tbl, idx, stat FROM sqlite_stat1"))
    finally:
        con.close()


def plan_under(path, stats, sql):
    con = apsw.Connection(path)
    con.execute("DELETE FROM sqlite_stat1")
    con.executemany("INSERT INTO sqlite_stat1 (tbl, idx, stat) VALUES (?, ?, ?)", stats)
    con.close()
    con = apsw.Connection(path, flags=apsw.SQLITE_OPEN_READONLY)
    try:
        return [r[-1] for r in con.execute("EXPLAIN QUERY PLAN " + sql)]
    finally:
        con.close()


print("sqlite:", apsw.sqlite_lib_version())
with_trigger = stats_of(trigger_db)
without = stats_of(notrigger_db)
print("statistics rows: with trigger %d, without %d" % (len(with_trigger), len(without)))
print()

work = "%s/stats-work.sqlite" % workdir
shutil.copy(base_db, work)

same = 0
for label, (literal, const) in QUERIES.items():
    sql = literal if literal else extract(const)
    a = plan_under(work, with_trigger, sql)
    b = plan_under(work, without, sql)
    if a == b:
        same += 1
        print("same   %s" % label)
        for line in a:
            print("           %s" % line)
    else:
        print("DIFFER %s" % label)
        for line in a:
            print("   with     %s" % line)
        for line in b:
            print("   without  %s" % line)
    print()

print("%d of %d queries plan identically under the two sets of statistics"
      % (same, len(QUERIES)))
