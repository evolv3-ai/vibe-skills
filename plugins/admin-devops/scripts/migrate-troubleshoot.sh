#!/usr/bin/env bash
# Migrate legacy troubleshoot notes to incident record format (QA #12).
set -euo pipefail
in="${1:-}"
out="${2:-incident.json}"
[[ -n "$in" && -f "$in" ]] || { echo "usage: migrate-troubleshoot.sh <legacy-note> [out]" >&2; exit 1; }
id=$(basename "$in" .md)
title=$(grep -m1 '^# ' "$in" 2>/dev/null | sed 's/^# *//' || echo "$id")
python3 - "$id" "$title" "$in" "$out" <<'PY'
import json, sys, datetime
inc = {
  "id": sys.argv[1],
  "severity": "sev3",
  "owner": "unassigned",
  "impact": sys.argv[2],
  "timeline": [{"at": datetime.datetime.utcnow().isoformat() + "Z", "note": f"migrated from {sys.argv[3]}"}],
  "runbook_links": []
}
open(sys.argv[4], "w").write(json.dumps(inc, indent=2) + "\n")
print(sys.argv[4])
PY
