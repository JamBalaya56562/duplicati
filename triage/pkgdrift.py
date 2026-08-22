#!/usr/bin/env python3
"""出荷ソリューション (Duplicati.slnx) で解決後のパッケージ版が分裂しているものを列挙する。

推移的依存まで含めた「実際に解決された版」を見るため obj/project.assets.json を読む。
csproj の PackageReference だけを見ると分裂の大半を見落とす。

    mise exec dotnet -- dotnet restore Duplicati.slnx    # 必ず先に実行すること
    mise exec python  -- python -u triage/pkgdrift.py

restore を省くと古い assets を読んで誤った結論が出る。
"""
import os, json, collections, datetime, re, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

slnx = open(os.path.join(root, "Duplicati.slnx"), encoding="utf-8-sig", errors="replace").read()
shipping = set()
for m in re.finditer(r'Path="([^"]+\.csproj)"', slnx):
    shipping.add(os.path.normpath(os.path.join(root, m.group(1).replace("/", os.sep))).lower())

vers = collections.defaultdict(lambda: collections.defaultdict(set))
times, used = [], 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".sl", ".git", "node_modules")]
    if "project.assets.json" not in filenames:
        continue
    fp = os.path.join(dirpath, "project.assets.json")
    try:
        d = json.load(open(fp, encoding="utf-8-sig", errors="replace"))
    except Exception:
        continue
    proj = d.get("project", {}).get("restore", {}).get("projectPath", "")
    if not proj or os.path.normpath(proj).lower() not in shipping:
        continue
    used += 1
    times.append(os.path.getmtime(fp))
    name = os.path.basename(proj)
    for tgt in d.get("targets", {}).values():
        for entry in tgt:
            if "/" in entry:
                pkg, v = entry.rsplit("/", 1)
                vers[pkg][v].add(name)

print("projects in Duplicati.slnx: %d" % len(shipping))
print("assets files used         : %d" % used)
if times:
    fmt = lambda t: datetime.datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M")
    print("assets mtime range        : %s .. %s" % (fmt(min(times)), fmt(max(times))))
print("distinct packages resolved: %d" % len(vers))

split = {k: v for k, v in vers.items() if len(v) > 1}
print("SPLIT packages            : %d\n" % len(split))
for pkg in sorted(split):
    print("### %s" % pkg)
    for v in sorted(split[pkg]):
        projs = sorted(split[pkg][v])
        shown = ", ".join(projs[:4]) + (" ...(+%d)" % (len(projs) - 4) if len(projs) > 4 else "")
        print("    %-14s %s" % (v, shown))
    print()
