#!/usr/bin/env python3
"""あるパッケージが特定の版に押し上げられている原因（要求元）を辿る。

pkgdrift.py が分裂を見つけたあと、「なぜ一部のプロジェクトだけ高い版になるのか」を
突き止めるために使う。assets の依存グラフから、その版以上を要求している側を列挙する。

    mise exec python -- python -u triage/pkgdrift-root.py Microsoft.Extensions.Primitives 10.0.3

第2引数を省くと、そのパッケージの解決版をプロジェクト数とともに一覧するだけ。
"""
import os, json, collections, re, sys

if len(sys.argv) < 2:
    sys.exit(__doc__)
TARGET = sys.argv[1]
HIGH = sys.argv[2] if len(sys.argv) > 2 else None

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

slnx = open(os.path.join(root, "Duplicati.slnx"), encoding="utf-8-sig", errors="replace").read()
shipping = {}
for m in re.finditer(r'Path="([^"]+\.csproj)"', slnx):
    p = os.path.normpath(os.path.join(root, m.group(1).replace("/", os.sep)))
    shipping[p.lower()] = os.path.basename(p)

resolved = collections.defaultdict(set)   # version -> projects
demanders = set()                          # "requester version (asks range)"

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
    key = os.path.normpath(proj).lower() if proj else ""
    if key not in shipping:
        continue
    name = shipping[key]
    for tgt in d.get("targets", {}).values():
        for entry, info in tgt.items():
            if "/" not in entry:
                continue
            pkg, v = entry.rsplit("/", 1)
            if pkg == TARGET:
                resolved[v].add(name)
            for dep, req in (info.get("dependencies") or {}).items():
                if dep == TARGET and (HIGH is None or req.startswith(HIGH)):
                    demanders.add("%s %s  (asks %s)" % (pkg, v, req))

print("### %s" % TARGET)
for v in sorted(resolved):
    print("  resolved %-14s in %d project(s)" % (v, len(resolved[v])))
print()
if HIGH:
    print("  who demands %s :" % HIGH)
    if not demanders:
        print("    (none — came in via a direct PackageReference, check the csproj files)")
    for line in sorted(demanders):
        print("    <- %s" % line)
