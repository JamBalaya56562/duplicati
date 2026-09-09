# Reads back the rows the TLS patch added, and checks the script stream matches the file.
import msilib, sys, pathlib, hashlib, tempfile, os
msi, script = sys.argv[1], pathlib.Path(sys.argv[2])
db = msilib.OpenDatabase(msi, msilib.MSIDBOPEN_READONLY)
def rows(sql, kinds):
    v = db.OpenView(sql); v.Execute(None); out = []
    while (r := v.Fetch()) is not None:
        out.append(tuple(r.GetInteger(i + 1) if k == 'i' else r.GetString(i + 1) for i, k in enumerate(kinds)))
    v.Close(); return out
for r in rows("SELECT `Action`, `Type`, `Source`, `Target` FROM `CustomAction` WHERE `Action` = 'SetTrayIconHostUrlHttps' OR `Action` = 'SetTrayIconHostUrlHttp' OR `Action` = 'SyncTrayIconHostUrl'", 'sis s'.replace(' ', '')):
    print('CustomAction', r)
for r in rows("SELECT `Action`, `Sequence`, `Condition` FROM `InstallUISequence` WHERE `Sequence` >= 1305 AND `Sequence` <= 1309", 'sis'):
    print('UISequence', r)
v = db.OpenView("SELECT `Name`, `Data` FROM `Binary` WHERE `Name` = 'SyncTrayIconHostUrlScript'"); v.Execute(None)
r = v.Fetch()
data = r.GetStream(2).read(1 << 20)
print('Binary stream matches the script file:', hashlib.sha256(data).hexdigest() == hashlib.sha256(script.read_bytes()).hexdigest(), len(data), 'bytes')
print('package code:', db.GetSummaryInformation(0).GetProperty(msilib.PID_REVNUMBER).decode())
