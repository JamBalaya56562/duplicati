using Microsoft.Data.Sqlite;

// Shows sqlite_stat1, and with "stale" rewrites every number in it to 1, the stale statistics
// that issue #7127 traced its hang to: the planner then believes every table holds one row.
var path = args[0];
var stale = args.Length > 1 && args[1] == "stale";
using var con = new SqliteConnection($"Data Source={path}");
con.Open();

using (var check = con.CreateCommand())
{
    check.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE name = 'sqlite_stat1'";
    if ((long)check.ExecuteScalar()! == 0)
    {
        Console.WriteLine("no sqlite_stat1");
        if (!stale)
            return;
        using var analyze = con.CreateCommand();
        analyze.CommandText = "ANALYZE";
        analyze.ExecuteNonQuery();
    }
}

if (stale)
{
    var rows = new List<(string tbl, string? idx, string stat)>();
    using (var read = con.CreateCommand())
    {
        read.CommandText = "SELECT tbl, idx, stat FROM sqlite_stat1";
        using var r = read.ExecuteReader();
        while (r.Read())
            rows.Add((r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1), r.GetString(2)));
    }
    using var tr = con.BeginTransaction();
    foreach (var (tbl, idx, stat) in rows)
    {
        var ones = string.Join(" ", stat.Split(' ').Select(p => long.TryParse(p, out _) ? "1" : p));
        using var upd = con.CreateCommand();
        upd.Transaction = tr;
        upd.CommandText = idx == null
            ? "UPDATE sqlite_stat1 SET stat = $s WHERE tbl = $t AND idx IS NULL"
            : "UPDATE sqlite_stat1 SET stat = $s WHERE tbl = $t AND idx = $i";
        upd.Parameters.AddWithValue("$s", ones);
        upd.Parameters.AddWithValue("$t", tbl);
        if (idx != null)
            upd.Parameters.AddWithValue("$i", idx);
        upd.ExecuteNonQuery();
    }
    tr.Commit();
}

using (var show = con.CreateCommand())
{
    show.CommandText = "SELECT tbl, idx, stat FROM sqlite_stat1 WHERE tbl IN ('FilesetEntry', 'FileLookup', 'Blockset', 'BlocksetEntry', 'Metadataset', 'PathPrefix') ORDER BY tbl, idx LIMIT 12";
    using var r = show.ExecuteReader();
    while (r.Read())
        Console.WriteLine($"{r.GetString(0)} | {(r.IsDBNull(1) ? "" : r.GetString(1))} | {r.GetString(2)}");
}
