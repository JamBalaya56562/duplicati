# Makes a copy of the official 2.4.1.0 MSI with the SyncTrayIconHostUrl change of the branch (#7804):
# a Binary with the script, three CustomAction rows and three InstallUISequence rows, with the same
# conditions as Duplicati.wxs (unescaped). Usage: patch-msi-7804-tls.py <msi folder> <repo>
import msilib, shutil, sys, uuid, pathlib

folder, repo = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
script = repo / 'ReleaseBuilder/Resources/Windows/TrayIcon/SyncTrayIconHostUrl.js'
src = folder / 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
dst = folder / 'duplicati-2.4.1.0-patched-7804-tls.msi'
shutil.copyfile(src, dst)

base = ('PREVIOUS_SERVICE_INSTALLED="1" AND (&DuplicatiServiceFeature=3 OR (!DuplicatiServiceFeature=3 AND NOT &DuplicatiServiceFeature=2))'
        ' AND NOT REMOVE~="ALL" AND NOSCRIPT <> "true"')
tls_after = '(&DuplicatiTlsCertsFeature=3 OR (!DuplicatiTlsCertsFeature=3 AND NOT &DuplicatiTlsCertsFeature=2))'
sequence = [
    ('SetTrayIconHostUrlHttps', f'{base} AND &DuplicatiTlsCertsFeature=3', 1307),
    ('SetTrayIconHostUrlHttp', f'{base} AND NOT {tls_after} AND (&DuplicatiTlsCertsFeature=2 OR PREVIOUSVERSIONSINSTALLED)', 1308),
    ('SyncTrayIconHostUrl', f'TRAYICON_HOSTURL AND {base}', 1309),
]
actions = [
    ('SetTrayIconHostUrlHttps', 51, 'TRAYICON_HOSTURL', 'https://127.0.0.1:8200'),
    ('SetTrayIconHostUrlHttp', 51, 'TRAYICON_HOSTURL', 'http://127.0.0.1:8200'),
    # 69 = JScript in a Binary (5) + ignore the return code (64), as StoreTrayIconValues
    ('SyncTrayIconHostUrl', 69, 'SyncTrayIconHostUrlScript', 'CustomAction'),
]

db = msilib.OpenDatabase(str(dst), msilib.MSIDBOPEN_TRANSACT)
rec = msilib.CreateRecord(2)
rec.SetString(1, 'SyncTrayIconHostUrlScript')
rec.SetStream(2, str(script))
v = db.OpenView('INSERT INTO `Binary` (`Name`, `Data`) VALUES (?, ?)'); v.Execute(rec); v.Close()
for name, typ, source, target in actions:
    r = msilib.CreateRecord(4)
    r.SetString(1, name); r.SetInteger(2, typ); r.SetString(3, source); r.SetString(4, target)
    v = db.OpenView('INSERT INTO `CustomAction` (`Action`, `Type`, `Source`, `Target`) VALUES (?, ?, ?, ?)'); v.Execute(r); v.Close()
for name, cond, seq in sequence:
    r = msilib.CreateRecord(3)
    r.SetString(1, name); r.SetString(2, cond); r.SetInteger(3, seq)
    v = db.OpenView('INSERT INTO `InstallUISequence` (`Action`, `Condition`, `Sequence`) VALUES (?, ?, ?)'); v.Execute(r); v.Close()
si = db.GetSummaryInformation(1)
si.SetProperty(msilib.PID_REVNUMBER, '{' + str(uuid.uuid4()).upper() + '}')
si.Persist()
db.Commit()
print('patched:', dst)
