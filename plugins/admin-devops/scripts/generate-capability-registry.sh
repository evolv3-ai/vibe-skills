#!/usr/bin/env bash
# Populate artifacts/capability-registry.json from skills tree (QA #7).
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$BASE/artifacts"
out="$BASE/artifacts/capability-registry.json"
tmp="$out.tmp.$$"

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
caps=()
while IFS= read -r f; do
  name="$(basename "$(dirname "$f")")"
  caps+=("{\"name\":\"$name\",\"skill\":\"$f\"}")
done < <(find "$BASE/skills" -maxdepth 2 -name SKILL.md -type f 2>/dev/null | sort)

joined=$(IFS=,; echo "${caps[*]:-}")
printf '{"version":"1.0.0","generated_at":"%s","capabilities":[%s]}\n' "$generated_at" "$joined" > "$tmp"
mv "$tmp" "$out"
echo "{\"ok\":true,\"count\":${#caps[@]},\"out\":\"$out\"}"
