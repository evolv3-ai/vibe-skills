#!/usr/bin/env bash
# Bash<->PowerShell contract parity (QA #1).
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sh_out=$("$BASE/scripts/validate-contract.sh")
if command -v pwsh >/dev/null 2>&1; then
  ps_out=$(pwsh -NoProfile -File "$BASE/scripts/validate-contract.ps1" | tr -d '\r')
  if [[ "$sh_out" == "$ps_out" ]]; then
    echo '{"ok":true,"shells":["bash","pwsh"]}'
  else
    printf '{"ok":false,"bash":%s,"pwsh":%s}\n' "$sh_out" "$ps_out"
    exit 1
  fi
else
  printf '{"ok":true,"shells":["bash"],"note":"pwsh not installed"}\n'
fi
