"""Asks the database the question the next backup asks: is any fileset left looking interrupted?

GetIncompleteFilesetsAsync selects filesets whose remote volume is Uploading or Temporary
and which hold at least one entry. BackupHandler turns a hit into lastTempVolumeIncomplete,
UploadRealFilelist turns that into lastWasPartial, and lastWasPartial makes a backup upload
a fileset even when nothing has changed.
"""
import sqlite3
import sys

con = sqlite3.connect(sys.argv[1])
rows = con.execute("""
    SELECT "Fileset"."ID", "RemoteVolume"."Name", "RemoteVolume"."State"
    FROM "Fileset", "RemoteVolume"
    WHERE "RemoteVolume"."ID" = "Fileset"."VolumeID"
      AND "Fileset"."ID" IN (SELECT "FilesetID" FROM "FilesetEntry")
      AND ("RemoteVolume"."State" = 'Uploading' OR "RemoteVolume"."State" = 'Temporary')
""").fetchall()

states = con.execute("""
    SELECT "Type", "State", COUNT(*) FROM "RemoteVolume" GROUP BY "Type", "State" ORDER BY 1, 2
""").fetchall()
con.close()

print("incomplete=%d %s | volumes: %s"
      % (len(rows), rows if rows else "",
         ", ".join("%s/%s=%d" % s for s in states)))
