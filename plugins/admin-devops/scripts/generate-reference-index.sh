#!/usr/bin/env bash
# Generate provider/platform reference index (QA #8).
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$BASE/docs/provider-reference-index.json"
mkdir -p "$(dirname "$out")"
items=()
while IFS= read -r f; do
  rel="${f#$BASE/}"
  skill="$(basename "$(dirname "$(dirname "$f")")")"
  items+=("{\"skill\":\"$skill\",\"file\":\"$rel\"}")
done < <(find "$BASE/skills" -path '*/references/*.md' -type f 2>/dev/null | sort)
joined=$(IFS=,; echo "${items[*]:-}")
printf '[%s]\n' "$joined" > "$out"
echo "{\"ok\":true,\"count\":${#items[@]},\"out\":\"$out\"}"
