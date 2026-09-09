# Makes a copy of the official 2.4.1.0 MSI with only the two shortcut-argument conditions changed (#7804),
# and checks that the edited .wxs files are well-formed XML. Usage: patch-msi-7804.py <msi folder> <repo>
import msilib, shutil, sys, uuid, pathlib, xml.etree.ElementTree as ET

folder, repo = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for rel in ('ReleaseBuilder/Resources/Windows/TrayIcon/Duplicati.wxs', 'ReleaseBuilder/Resources/Windows/TrayIcon/Shortcuts.wxs'):
    ET.parse(repo / rel)
    print(f"well-formed: {rel}")

src = folder / 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
dst = folder / 'duplicati-2.4.1.0-patched-7804.msi'
shutil.copyfile(src, dst)

installed = '&DuplicatiServiceFeature=3 OR (!DuplicatiServiceFeature=3 AND NOT &DuplicatiServiceFeature=2)'
new = {'SetNoHostedServerArg': installed, 'ClearNoHostedServerArg': f'NOT ({installed})'}

def conditions(db):
    v = db.OpenView("SELECT `Action`, `Condition`, `Sequence` FROM `InstallExecuteSequence` WHERE `Action` = 'SetNoHostedServerArg' OR `Action` = 'ClearNoHostedServerArg'")
    v.Execute(None)
    out = {}
    while (r := v.Fetch()) is not None:
        out[r.GetString(1)] = (r.GetString(2), r.GetInteger(3))
    v.Close()
    return out

db = msilib.OpenDatabase(str(dst), msilib.MSIDBOPEN_TRANSACT)
print('before:', conditions(db))
for action, cond in new.items():
    v = db.OpenView(f"UPDATE `InstallExecuteSequence` SET `Condition` = '{cond}' WHERE `Action` = '{action}'")
    v.Execute(None); v.Close()
si = db.GetSummaryInformation(1)
old_code = si.GetProperty(msilib.PID_REVNUMBER)
si.SetProperty(msilib.PID_REVNUMBER, '{' + str(uuid.uuid4()).upper() + '}')
si.Persist()
db.Commit()
db.Close()
