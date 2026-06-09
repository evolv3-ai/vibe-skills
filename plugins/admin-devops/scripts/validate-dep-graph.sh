#!/usr/bin/env bash
# Validate dependency graph (QA #7): duplicates, missing deps, cycles.
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
graph="$BASE/artifacts/dependency-graph.json"
[[ -f "$graph" ]] || { echo '{"ok":false,"error":"DEPENDENCY_GRAPH_INVALID","message":"missing dependency-graph.json"}'; exit 1; }
python3 - "$graph" <<'PY'
import json, sys
g = json.load(open(sys.argv[1]))
components = g.get("components", [])
ids = [c["id"] for c in components]
dupes = sorted({n for n in ids if ids.count(n) > 1})
if dupes:
    print(json.dumps({"ok": False, "error": "DEPENDENCY_GRAPH_INVALID", "duplicates": dupes}))
    sys.exit(1)
ids_set = set(ids)
missing = []
for c in components:
    for d in c.get("deps", []):
        if d not in ids_set:
            missing.append([c["id"], d])
if missing:
    print(json.dumps({"ok": False, "error": "DEPENDENCY_GRAPH_INVALID", "missing_deps": missing}))
    sys.exit(1)
adj = {c["id"]: list(c.get("deps", [])) for c in components}
WHITE, GRAY, BLACK = 0, 1, 2
color = {n: WHITE for n in adj}
def dfs(n, path):
    color[n] = GRAY
    for d in adj.get(n, []):
        if color.get(d, BLACK) == GRAY:
            return path + [n, d]
        if color.get(d, BLACK) == WHITE:
            r = dfs(d, path + [n])
            if r:
                return r
    color[n] = BLACK
    return None
for n in list(adj):
    if color[n] == WHITE:
        cyc = dfs(n, [])
        if cyc:
            print(json.dumps({"ok": False, "error": "DEPENDENCY_GRAPH_INVALID", "cycle": cyc}))
            sys.exit(1)
print(json.dumps({"ok": True, "components": len(components)}))
PY
