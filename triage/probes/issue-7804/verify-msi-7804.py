# Reads the two conditions and the package codes of the original and the patched MSI.
import msilib, sys
for path in sys.argv[1:]:
    db = msilib.OpenDatabase(path, msilib.MSIDBOPEN_READONLY)
    v = db.OpenView("SELECT `Action`, `Condition` FROM `InstallExecuteSequence` WHERE `Action` = 'SetNoHostedServerArg' OR `Action` = 'ClearNoHostedServerArg'")
    v.Execute(None)
    rows = []
    while (r := v.Fetch()) is not None:
        rows.append(f"{r.GetString(1)}: {r.GetString(2)}")
    print(__import__("pathlib").Path(path).name, "package", db.GetSummaryInformation(0).GetProperty(msilib.PID_REVNUMBER).decode())
    for x in sorted(rows): print('   ', x)
