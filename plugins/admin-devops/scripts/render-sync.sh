#!/usr/bin/env bash
# Incremental, hash-based render/sync (QA #13). cwd-independent.
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$BASE/artifacts/render-hashes.json"
no_cache="false"; refresh="false"
for a in "$@"; do
  [[ "$a" == "--no-cache" ]] && no_cache="true"
  [[ "$a" == "--refresh-cache" ]] && refresh="true"
done
[[ "$no_cache" == "true" ]] && rm -f "$manifest"

input_dir="$BASE/skills/devops/references"
out="$BASE/artifacts/generated-reference-index.md"
mkdir -p "$(dirname "$out")"

if [[ ! -d "$input_dir" ]]; then
  echo "{\"ok\":false,\"error\":\"input_dir_missing\",\"path\":\"$input_dir\"}" >&2
  exit 1
fi

files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$input_dir" -maxdepth 1 -type f -name '*.md' | sort)
if (( ${#files[@]} == 0 )); then
  echo "{\"ok\":true,\"changed\":false,\"reason\":\"no inputs\"}"
  exit 0
fi
hash=$(cat "${files[@]}" | sha256sum | awk '{print $1}')

old=""
if [[ -f "$manifest" ]] && command -v jq >/dev/null 2>&1; then
  old=$(jq -r '.entries.reference_index // ""' "$manifest" 2>/dev/null || echo "")
fi

if [[ "$hash" != "$old" || "$refresh" == "true" ]]; then
  { echo '# Provider Reference Index'; for f in "${files[@]}"; do echo "- $(basename "$f")"; done; } > "$out"
  printf '{"version":"1.0.0","entries":{"reference_index":"%s"}}\n' "$hash" > "$manifest"
  echo "{\"ok\":true,\"changed\":true,\"out\":\"$out\"}"
else
  echo "{\"ok\":true,\"changed\":false,\"out\":\"$out\"}"
fi
