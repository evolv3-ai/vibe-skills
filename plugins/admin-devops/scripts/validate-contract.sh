#!/usr/bin/env bash
# Contract validator (QA #1).
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$BASE/contracts/contract.v1.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
required = ["version", "routing", "profile", "secrets", "logging", "commands"]
missing = [k for k in required if k not in doc]
if missing:
    print(json.dumps({"ok": False, "missing": missing}))
    sys.exit(1)
print(json.dumps({"ok": True, "version": doc.get("version")}))
PY
