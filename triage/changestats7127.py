"""Times the change-statistics counting queries as the fileset grows.

UpdateChangeStatisticsAsync runs immediately before the phase the report blames. It builds
a temp table holding the previous fileset and the current one, indexes it on (PrefixID,
Path), and then runs nine counting queries, each a correlated NOT EXISTS or a join back
against that same table:

    SELECT COUNT(*) FROM tmp "A"
    WHERE "Source" = 1
      AND NOT EXISTS (SELECT 1 FROM tmp "B"
                      WHERE "B"."Source" = 0
                        AND "B"."PrefixID" = "A"."PrefixID"
                        AND "B"."Path" = "A"."Path")

That is the classic shape for a quadratic when the index is not used, and the temp table
has no statistics of its own, so what the planner does with it is worth checking rather
than assuming. If the cost per row grows with the row count, this is the superlinear
behaviour the report describes and everything measured so far has failed to find.

SQLite 3.53.4, the version the product ships, with the pragmas Duplicati sets that could
bear on a temp table.
"""
import sys
import time

import apsw

sizes = [1000, 4000, 16000, 64000, 128000]

ADDED = """
SELECT COUNT(*)
FROM "tmp_changes" "A"
WHERE
    "Source" = 1
    AND NOT EXISTS (
        SELECT 1
        FROM "tmp_changes" "B"
        WHERE
            "B"."Source" = 0
            AND "B"."PrefixID" = "A"."PrefixID"
            AND "B"."Path" = "A"."Path"
    )
    AND "A"."BlocksetID" NOT IN (-100, -200)
"""

MODIFIED = """
SELECT COUNT(*)
FROM "tmp_changes" "A"
WHERE
    "Source" = 1
    AND EXISTS (
        SELECT 1
        FROM "tmp_changes" "B"
        WHERE
            "B"."Source" = 0
            AND "B"."PrefixID" = "A"."PrefixID"
            AND "B"."Path" = "A"."Path"
            AND "B"."Metahash" != "A"."Metahash"
    )
    AND "A"."BlocksetID" NOT IN (-100, -200)
"""

print("sqlite:", apsw.sqlite_lib_version())
print()
print("%-9s %-11s %-11s %-11s %s" % ("files", "build", "added", "modified", "us per file"))

for n in sizes:
    con = apsw.Connection(":memory:")
    con.execute("PRAGMA temp_store=MEMORY")

    start = time.perf_counter()
    con.execute("""
        CREATE TEMP TABLE "tmp_changes" (
            "PrefixID" INTEGER, "Path" TEXT, "BlocksetID" INTEGER,
            "Metahash" TEXT, "Source" INTEGER)
    """)
    # Source 0 is the previous fileset, source 1 the current one. Same paths in both,
    # which is the unchanged-source case the report is about.
    con.executemany(
        'INSERT INTO "tmp_changes" VALUES (?, ?, ?, ?, ?)',
        ((1, "file-%08d" % i, 1, "meta-%d" % i, src)
         for src in (0, 1) for i in range(n)))
    con.execute('CREATE INDEX "idx_tmp_changes" ON "tmp_changes" ("PrefixID", "Path")')
    build = time.perf_counter() - start

    results = []
    for sql in (ADDED, MODIFIED):
        plan = [r[-1] for r in con.execute("EXPLAIN QUERY PLAN " + sql)]
        start = time.perf_counter()
        list(con.execute(sql))
        results.append((time.perf_counter() - start, plan))

    con.close()
    total = results[0][0] + results[1][0]
    print("%-9d %-11.3f %-11.3f %-11.3f %.2f"
          % (n, build, results[0][0], results[1][0], total * 1e6 / n))
    for label, (_, plan) in zip(("added", "modified"), results):
        for line in plan:
            print("      %-9s %s" % (label, line))
