I could reproduce a hang in the same consistency check with 2.0.6.1. It came from stale query statistics, the cause found for the similar #7127.

I used the official Docker images, with 100,000 small files in 100 folders and three backups:

- With the statistics as SQLite left them, 2.0.6.1 finished the check at the start of each backup in under 0.5 s.
- Before the third backup, I set every number in `sqlite_stat1` to 1, so the planner believes every table holds one row. 2.0.6.1 then did not finish within 15 minutes. It was still in the first query of the check (`SELECT "CalcLen", "Length", "A"."BlocksetID", "File"."Path" FROM ...`, which is also in the log above). I saw this twice.
- 2.4.1.0, with the same data and the same change to `sqlite_stat1`, finished the third backup in 58 s, and the check took 1.2 s.

Since 2.4.0.0, a backup rebuilds the query statistics before these checks when they no longer describe the database (9b9cfb623e10e2538ca40157ad87acca81222125). I do not know if stale statistics were the cause in the database here. A first backup that started on almost empty tables can leave such numbers behind, as in #7127.

If this still happens on 2.4.0.0 or later, a copy of `sqlite_stat1` from the job database would help to tell. Otherwise I think this can be closed.
