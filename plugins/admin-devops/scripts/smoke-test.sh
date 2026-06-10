#!/usr/bin/env bash
# Smoke test for v5 wiring. Exits non-zero if any gate misbehaves.
set -uo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
expect_exit() {
  local label="$1" expected="$2"; shift 2
  "$@" >/dev/null 2>&1
  local rc=$?
  if (( rc == expected )); then
    echo "  [pass] $label (exit=$rc)"
  else
    echo "  [FAIL] $label expected=$expected got=$rc"
    fail=1
  fi
}

echo "Smoke test:"
expect_exit "preflight valid -> 0"     0 "$BASE/scripts/profile-preflight.sh" "$BASE/tests/fixtures/profile/valid.json" --json
expect_exit "preflight invalid -> 3"   3 "$BASE/scripts/profile-preflight.sh" "$BASE/tests/fixtures/profile/invalid.json" --json
expect_exit "preflight flag-first valid -> 0"   0 "$BASE/scripts/profile-preflight.sh" --json "$BASE/tests/fixtures/profile/valid.json"
expect_exit "preflight flag-first invalid -> 3" 3 "$BASE/scripts/profile-preflight.sh" --json "$BASE/tests/fixtures/profile/invalid.json"
expect_exit "preflight unknown flag -> 2"       2 "$BASE/scripts/profile-preflight.sh" --bogus "$BASE/tests/fixtures/profile/valid.json"
expect_exit "validate-contract -> 0"   0 "$BASE/scripts/validate-contract.sh"
expect_exit "validate-dep-graph -> 0"  0 "$BASE/scripts/validate-dep-graph.sh"
expect_exit "doctor -> 0"              0 "$BASE/scripts/doctor.sh" --json
expect_exit "provider-core health -> 0" 0 "$BASE/scripts/provider-core.sh" "$BASE/scripts/provider-adapter-template.sh" health_check

# coolify-fix-dns must fail fast (no network) when TUNNEL_HOSTNAME is missing,
# and must be executable (repo rule).
DNS_SCRIPT="$BASE/skills/coolify/scripts/coolify-fix-dns.sh"
dns_out=$(env CLOUDFLARE_API_TOKEN=x CLOUDFLARE_ZONE_ID=x DNS_RECORD_ID=x TUNNEL_ID=x \
  CLOUDFLARE_ACCOUNT_ID=x TUNNEL_HOSTNAME="" timeout 15 bash "$DNS_SCRIPT" 2>&1)
dns_rc=$?
if [[ $dns_rc -eq 1 && "$dns_out" == *"Missing required environment variables"* ]]; then
  echo "  [pass] coolify-fix-dns missing TUNNEL_HOSTNAME -> 1"
else
  echo "  [FAIL] coolify-fix-dns missing TUNNEL_HOSTNAME expected=1+message got=$dns_rc"
  fail=1
fi
if [[ -x "$DNS_SCRIPT" ]]; then
  echo "  [pass] coolify-fix-dns executable"
else
  echo "  [FAIL] coolify-fix-dns not executable"
  fail=1
fi

if (( fail == 0 )); then
  echo '{"ok":true,"smoke":"passed"}'
else
  echo '{"ok":false,"smoke":"failed"}'
  exit 1
fi
