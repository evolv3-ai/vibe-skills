#!/usr/bin/env bash
# Strict profile preflight gate (QA #2). cwd-independent paths.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_PATH="${1:-${ADMIN_PROFILE_PATH:-$BASE/tests/fixtures/profile/valid.json}}"
MODE="text"
FIX=0
for arg in "$@"; do
  case "$arg" in
    --json) MODE="json" ;;
    --fix-suggestions) FIX=1 ;;
  esac
done
if [[ ! -f "$PROFILE_PATH" ]]; then
  if [[ "$MODE" == "json" ]]; then
    printf '{"ok":false,"error_code":"PROFILE_MISSING","profile":"%s"}\n' "$PROFILE_PATH"
  else
    echo "PROFILE_MISSING: $PROFILE_PATH"
  fi
  exit 2
fi
python3 - "$PROFILE_PATH" "$MODE" "$FIX" <<'PY'
import json, sys
profile_path, mode, fix = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    p = json.load(open(profile_path))
except Exception as e:
    out = {"ok": False, "error_code": "PROFILE_INVALID", "message": f"parse error: {e}"}
    print(json.dumps(out) if mode == "json" else f"PROFILE_INVALID: {e}")
    sys.exit(3)
required = ["schemaVersion", "bindings", "consumer", "secretsConfig"]
missing = [k for k in required if k not in p]
sc = p.get("secretsConfig", {})
if "secretsConfig" not in missing and "primaryBackend" not in sc:
    missing.append("secretsConfig.primaryBackend")
if missing:
    out = {"ok": False, "error_code": "PROFILE_INVALID", "missing": missing}
    if fix == "1":
        out["fix_suggestions"] = [f"Add '{k}' to profile" for k in missing]
    print(json.dumps(out) if mode == "json" else f"PROFILE_INVALID: missing {', '.join(missing)}")
    sys.exit(3)
out = {"ok": True, "profile": profile_path}
print(json.dumps(out) if mode == "json" else "OK: profile valid")
PY
