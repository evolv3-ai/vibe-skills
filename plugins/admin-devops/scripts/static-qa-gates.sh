#!/usr/bin/env bash
# Static QA / release gate runner (QA #15).
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
run() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  [pass] $name"
  else
    echo "  [FAIL] $name"
    fail=1
  fi
}

echo "Static QA gates:"
run "validate-contract.sh"          "$BASE/scripts/validate-contract.sh"
run "profile-preflight valid"       "$BASE/scripts/profile-preflight.sh" "$BASE/tests/fixtures/profile/valid.json" --json
run "validate-dep-graph.sh"         "$BASE/scripts/validate-dep-graph.sh"

# Content-hash duplicate-artifact detection (only within artifacts/).
art_dir="$BASE/artifacts"
if [[ -d "$art_dir" ]]; then
  dup_hashes=$(find "$art_dir" -type f -exec sha256sum {} \; 2>/dev/null | awk '{print $1}' | sort | uniq -d || true)
  if [[ -n "$dup_hashes" ]]; then
    echo "  [warn] duplicate artifact content detected"
    for h in $dup_hashes; do
      find "$art_dir" -type f -exec sha256sum {} \; 2>/dev/null | awk -v hh="$h" '$1==hh {print "         " $2}'
    done
  else
    echo "  [pass] no duplicate artifact content"
  fi
fi

# Markdown link existence sweep (relative links only, opt-in).
if [[ "${QA_CHECK_MD_LINKS:-0}" == "1" ]]; then
  broken=0
  while IFS= read -r md; do
    while IFS= read -r link; do
      target="$(dirname "$md")/$link"
      [[ -e "$target" ]] || { echo "  [warn] broken link: $md -> $link"; broken=1; }
    done < <(grep -oE '\]\([^)#h][^)]*\)' "$md" 2>/dev/null | sed 's/^](//' | sed 's/)$//' | grep -v '^https\?:' || true)
  done < <(find "$BASE" -name '*.md' -type f 2>/dev/null)
  (( broken == 0 )) && echo "  [pass] markdown links"
fi

if (( fail == 0 )); then
  echo '{"ok":true}'
else
  echo '{"ok":false}'
  exit 1
fi
