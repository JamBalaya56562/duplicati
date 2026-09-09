import msilib, glob, sys, re, os
def q(db, sql, n):
    v = db.OpenView(sql); v.Execute(None); out = []
    while True:
        try: r = v.Fetch()
        except msilib.MSIError: break
        if r is None: break
        out.append(" | ".join((r.GetString(i) or "") for i in range(1, n+1)))
    v.Close(); return out
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.msi"))):
    db = msilib.OpenDatabase(f, msilib.MSIDBOPEN_READONLY)
    print("=====", os.path.basename(f))
    print("ProductVersion:", q(db, "SELECT Value FROM Property WHERE Property='ProductVersion'", 1))
    print("Upgrade:", q(db, "SELECT UpgradeCode, VersionMin, VersionMax, ActionProperty FROM Upgrade", 4))
    print("Features:", q(db, "SELECT Feature, Level FROM Feature", 2))
    print("Feature conditions:", q(db, "SELECT Feature_, Level, Condition FROM Condition", 3))
    for t in ("InstallUISequence", "InstallExecuteSequence"):
        rows = [r for r in q(db, f"SELECT Action, Condition, Sequence FROM {t}", 3) if re.search(r"TLS|AppSearch|MigrateFeatureStates|RemoveExistingProducts|UpgradeSentinel|FindRelatedProducts", r)]
        print(t + ":"); [print("  ", r[:230]) for r in rows]
    print("Properties:", [r[:200] for r in q(db, "SELECT Property, Value FROM Property", 2) if re.search(r"TLS|SecureCustom", r)])
    v = db.OpenView("SELECT Attributes FROM Upgrade"); v.Execute(None); attrs=[]
    while True:
        r = v.Fetch()
        if r is None: break
        attrs.append(r.GetInteger(1))
    print("Upgrade Attributes:", attrs, "MigrateFeatures(bit 1) set:", [bool(a & 1) for a in attrs])
