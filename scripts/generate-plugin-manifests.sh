#!/bin/bash
# Generate plugin.json for all skills
# Extracts metadata from SKILL.md frontmatter

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../skills" && pwd)"

echo "Generating plugin.json files for all skills..."
echo "Skills directory: $SKILLS_DIR"
echo ""

# Counter for tracking progress
count=0
total=$(ls -1 "$SKILLS_DIR" | wc -l)

# Iterate through all skill directories
for skill_dir in "$SKILLS_DIR"/*; do
  if [ ! -d "$skill_dir" ]; then
    continue
  fi

  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  plugin_dir="$skill_dir/.claude-plugin"
  plugin_json="$plugin_dir/plugin.json"

  count=$((count + 1))
  echo "[$count/$total] Processing: $skill_name"

  # Check if SKILL.md exists
  if [ ! -f "$skill_md" ]; then
    echo "  ⚠️  Warning: SKILL.md not found, skipping"
    continue
  fi

  # Create .claude-plugin directory
  mkdir -p "$plugin_dir"

  # Extract metadata from SKILL.md frontmatter
  # Look for YAML frontmatter between --- markers
  description=""
  keywords=""

  # Extract description (handle single-line, multi-line with |, and multi-line with >)
  # First try single-line format
  description=$(awk '/^description:/{if($0 !~ /[\|>]$/){gsub(/^description: */, ""); print; exit}}' "$skill_md")

  # If not found or empty, try multi-line format with | or >
  if [ -z "$description" ]; then
    description=$(awk '
      /^description: [\|>]/{flag=1; next}
      /^[a-z-]+:/{flag=0}
      flag && /^  /{gsub(/^  /, ""); line=line $0 " "}
      END{gsub(/ $/, "", line); print line}
    ' "$skill_md")
  fi

  # If description is still empty or problematic, use a default
  if [ -z "$description" ] || [ "$description" = "|" ] || [ "$description" = ">" ]; then
    description="Production-ready skill for $skill_name"
  fi

  # Extract keywords BEFORE truncating description
  # Keywords are in the format "Keywords: keyword1, keyword2, ..."
  keywords_raw=$(echo "$description" | grep -oP 'Keywords:\s*\K[^$]*' | tr -d '"' | tr -d "'")

  # If no keywords found in description, try YAML format
  if [ -z "$keywords_raw" ]; then
    keywords_raw=$(awk '/^keywords:/{flag=1; next} /^[a-z-]+:/{flag=0} flag && /^  - /{gsub(/^  - /, ""); print}' "$skill_md" | tr '\n' ',' | sed 's/,$//')
  fi

  # Clean up and convert keywords to JSON array
  keywords_json="[]"
  if [ -n "$keywords_raw" ]; then
    # Split by comma, trim whitespace, limit to first 15 keywords
    keywords_json=$(echo "$keywords_raw" | sed 's/,/\n/g' | sed 's/^ *//;s/ *$//' | grep -v '^$' | head -15 | awk '
      BEGIN { printf "[" }
      {
        gsub(/\\/, "\\\\")
        gsub(/"/, "")
        if (NR > 1) printf ","
        printf "\"%s\"", $0
      }
      END { printf "]" }
    ')
  fi

  # Now clean up description (remove Keywords line, trim, limit to 500 chars)
  description=$(echo "$description" | sed 's/Keywords:.*$//' | tr -d '"' | tr -d "'" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//' | head -c 500)

  # Detect agents in skill's agents/ directory
  agents_json="[]"
  agents_dir="$skill_dir/agents"
  if [ -d "$agents_dir" ]; then
    agent_list=$(find "$agents_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | while read -r agent_file; do
      basename "$agent_file" .md
    done | sort)
    if [ -n "$agent_list" ]; then
      agents_json=$(echo "$agent_list" | awk '
        BEGIN { printf "[" }
        { if (NR > 1) printf ","; printf "\"%s\"", $0 }
        END { printf "]" }
      ')
      echo "  📦 Found agents: $(echo "$agent_list" | tr '\n' ' ')"
    fi
  fi

  # Generate plugin.json
  cat > "$plugin_json" << EOF
{
  "name": "$skill_name",
  "description": "$description",
  "version": "1.0.0",
  "author": {
    "name": "Jeremy Dawes",
    "email": "jeremy@jezweb.net"
  },
  "license": "MIT",
  "repository": "https://github.com/jezweb/claude-skills",
  "keywords": $keywords_json,
  "agents": $agents_json
}
EOF

  echo "  ✅ Created: $plugin_json"
done

echo ""
echo "✅ Done! Generated plugin.json for $count skills"
echo ""
echo "Next steps:"
echo "1. Review generated files: find skills/ -name plugin.json"
echo "2. Test marketplace: /plugin marketplace add https://github.com/jezweb/claude-skills"
echo "3. Install a skill: /plugin install cloudflare-worker-base@claude-skills"
