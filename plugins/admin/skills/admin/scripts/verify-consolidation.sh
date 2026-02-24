#!/bin/bash
set -euo pipefail

SKILLS_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADMIN_SKILL="$SKILLS_ROOT/admin"
DEVOPS_SKILL="$SKILLS_ROOT/admin-devops"
ARCHIVE_DIR="$(cd "$SKILLS_ROOT/.." && pwd)/archive/skills"
ERRORS=0

log_fail() { echo "FAIL"; ((ERRORS++)); }

echo "=== Phase 5 Consolidation Verification ==="

# Test 1: Required directories exist
echo -n "Test 1: Directory structure... "
[ -d "$ADMIN_SKILL/references" ] && [ -d "$DEVOPS_SKILL/references" ] && echo "PASS" || log_fail

# Test 2: Required files exist
echo -n "Test 2: Required files... "
[ -f "$ADMIN_SKILL/references/windows.md" ] && \
[ -f "$ADMIN_SKILL/references/wsl.md" ] && \
[ -f "$ADMIN_SKILL/references/mcp.md" ] && \
[ -f "$DEVOPS_SKILL/references/hetzner.md" ] && \
[ -f "$DEVOPS_SKILL/references/coolify.md" ] && echo "PASS" || log_fail

# Test 3: Reference integrity (all referenced files exist)
echo -n "Test 3: Reference integrity... "
refs=$(grep -hEo "references/[A-Za-z0-9._{}-]+\.md" "$ADMIN_SKILL/SKILL.md" "$DEVOPS_SKILL/SKILL.md" | sort -u || true)
ok=1
for r in $refs; do
  [ "$r" = "references/{platform}.md" ] && continue
  [ -f "$ADMIN_SKILL/$r" ] || [ -f "$DEVOPS_SKILL/$r" ] || ok=0
  done
[ $ok -eq 1 ] && echo "PASS" || log_fail

# Test 4: Profile gate parity
echo -n "Test 4: Profile gate parity... "
cmp -s "$ADMIN_SKILL/references/profile-gate.md" "$DEVOPS_SKILL/references/profile-gate.md" && echo "PASS" || log_fail

# Test 5: Version files correct
echo -n "Test 5: Version files... "
[ "$(cat "$ADMIN_SKILL/VERSION")" = "0.0.3" ] && \
[ "$(cat "$DEVOPS_SKILL/VERSION")" = "0.0.3" ] && echo "PASS" || log_fail

# Test 6: Old skills archived (not deleted)
echo -n "Test 6: Old skills archived... "
[ -d "$ARCHIVE_DIR/admin-windows" ] && [ ! -d "$SKILLS_ROOT/admin-windows" ] && echo "PASS" || log_fail

# Test 7: Logging scripts present in admin-devops
echo -n "Test 7: Logging scripts in admin-devops... "
[ -f "$DEVOPS_SKILL/scripts/log-admin-event.sh" ] && [ -f "$DEVOPS_SKILL/scripts/Log-AdminEvent.ps1" ] && echo "PASS" || log_fail

# Summary
echo "=== Results: $((7-ERRORS))/7 tests passed ==="
[ $ERRORS -eq 0 ] && echo "Consolidation verified!" || echo "ERRORS: $ERRORS tests failed"
exit $ERRORS
