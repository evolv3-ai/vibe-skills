#!/usr/bin/env bash
# =============================================================================
# Admin Suite Skill Bug Escalator - Bash version for WSL/Unix
# =============================================================================
# Escalates a local issue file to a GitHub Issue on evolv3-ai/vibe-skills.
# Only posts skill-level bugs — those requiring code changes to the plugin.
#
# Usage:
#   ./post-skill-issue.sh ~/.admin/issues/issue_20260401_120000_bad_flag.md
#   source post-skill-issue.sh && post_skill_issue "/path/to/issue.md"
#
# Exit codes:
#   0 — posted successfully, duplicate skipped, or graceful fallback
#   2 — local issue file not found or malformed
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
GITHUB_REPO="evolv3-ai/vibe-skills"

# Source the logging function
# shellcheck source=log-admin-event.sh
source "${SCRIPT_DIR}/log-admin-event.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_resolve_admin_root() {
    if [[ -n "${ADMIN_ROOT:-}" ]]; then
        echo "$ADMIN_ROOT"; return
    fi
    local satellite="${HOME}/.admin/.env"
    if [[ -f "$satellite" ]]; then
        local root
        root=$(grep "^ADMIN_ROOT=" "$satellite" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$root" ]]; then echo "$root"; return; fi
    fi
    echo "${HOME}/.admin"
}

# Extract a single YAML frontmatter field from an issue file
# Usage: _fm_field "status" "$file_content"
_fm_field() {
    local field="$1"
    local content="$2"
    # Extract value between --- markers, then get field value
    echo "$content" | awk '/^---/{f=!f;next} f' | grep "^${field}:" \
        | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^["\x27]//' | sed 's/["\x27]$//'
}

# Extract a markdown section body (text between ## Section and next ##)
# Usage: _section "Context" "$file_content"
_section() {
    local header="$1"
    local content="$2"
    echo "$content" | awk -v hdr="## ${header}" '
        $0 == hdr { found=1; next }
        found && /^## / { found=0 }
        found { print }
    ' | sed '/^[[:space:]]*$/{ /./!d }' | sed 's/^[[:space:]]*//' \
      | awk 'NF > 0 { p=1 } p' | sed -e 's/[[:space:]]*$//'
}

# Determine component type from affected paths mentioned in issue text
# Returns: skill | agent | command (default: skill)
_detect_component_type() {
    local text="$1"
    if echo "$text" | grep -q "agents/"; then
        echo "agent"
    elif echo "$text" | grep -q "commands/"; then
        echo "command"
    else
        echo "skill"
    fi
}

# Extract the most likely affected file path (plugins/admin-devops/... pattern)
_detect_affected_file() {
    local text="$1"
    local match
    # Look for explicit plugin-relative paths
    match=$(echo "$text" | grep -oE 'plugins/admin-devops/[^[:space:]"`)]+' | head -1)
    if [[ -n "$match" ]]; then
        echo "$match"; return
    fi
    # Look for skills/ or agents/ or commands/ paths
    match=$(echo "$text" | grep -oE '(skills|agents|commands)/[^[:space:]"`)]+\.(md|sh|ps1|ts|py)' | head -1)
    if [[ -n "$match" ]]; then
        echo "$match"; return
    fi
    echo "(see issue body)"
}

# Map platform field to GitHub label
# Returns: linux | windows | cross-platform
_detect_platform_label() {
    local platform="$1"
    local full_text="$2"
    local has_sh=false has_ps1=false

    echo "$full_text" | grep -q '\.sh' && has_sh=true
    echo "$full_text" | grep -q '\.ps1' && has_ps1=true

    if [[ "$has_sh" == true && "$has_ps1" == true ]]; then
        echo "cross-platform"; return
    fi

    case "$platform" in
        windows) echo "windows" ;;
        wsl|linux|macos|ubuntu|debian) echo "linux" ;;
        *) echo "linux" ;;  # default
    esac
}

# Update a YAML frontmatter field in the issue file (in-place)
# Usage: _update_fm_field "github_issue_url" "https://..." "$filepath"
_update_fm_field() {
    local field="$1"
    local value="$2"
    local filepath="$3"

    if grep -q "^${field}:" "$filepath" 2>/dev/null; then
        # Field exists — update it
        sed -i "s|^${field}:.*|${field}: ${value}|" "$filepath"
    else
        # Field does not exist — insert after related_logs block or before closing ---
        # Find the line number of the closing --- (second occurrence)
        local close_line
        close_line=$(awk '/^---/{c++; if(c==2) print NR}' "$filepath")
        if [[ -n "$close_line" ]]; then
            sed -i "${close_line}i ${field}: ${value}" "$filepath"
        else
            # Fallback: append to end of frontmatter area isn't possible, just append to file
            echo "${field}: ${value}" >> "$filepath"
        fi
    fi
}

# Update tags array to add a new tag (non-duplicate)
_add_tag() {
    local new_tag="$1"
    local filepath="$2"

    local current_tags
    current_tags=$(grep "^tags:" "$filepath" | head -1 | sed 's/^tags:[[:space:]]*//')

    if echo "$current_tags" | grep -q "$new_tag"; then
        return 0  # already present
    fi

    if [[ "$current_tags" == "[]" ]]; then
        sed -i "s/^tags: \[\]/tags: [\"${new_tag}\"]/" "$filepath"
    else
        # Insert before closing ]
        sed -i "s/^tags: \[/tags: [\"${new_tag}\", /" "$filepath"
    fi
}

# ---------------------------------------------------------------------------
# Fallback — when gh is unavailable
# ---------------------------------------------------------------------------

_fallback_no_gh() {
    local filepath="$1"
    local reason="$2"
    local timestamp
    timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")

    echo -e "\033[1;33m[WARN]\033[0m gh CLI unavailable (${reason}). Marking issue for later escalation."

    # Update status to needs-escalation
    sed -i "s/^status:.*/status: needs-escalation/" "$filepath"

    # Add pending-github tag
    _add_tag "pending-github" "$filepath"

    # Append escalation status section if not already present
    if ! grep -q "## Escalation Status" "$filepath"; then
        cat >> "$filepath" <<EOF

## Escalation Status

GitHub escalation pending — gh CLI unavailable or unauthenticated at ${timestamp}.
Reason: ${reason}

To escalate manually when gh is available:
  post-skill-issue.sh "${filepath}"
EOF
    fi

    log_admin_event "Skill issue marked needs-escalation (gh unavailable): $(basename "$filepath")" "WARN"
    echo -e "\033[1;33m[WARN]\033[0m Issue updated with needs-escalation status. Run this script again when gh is available."
}

# ---------------------------------------------------------------------------
# Main function
# ---------------------------------------------------------------------------

post_skill_issue() {
    local issue_path="$1"

    # --- Input validation ---
    if [[ -z "$issue_path" ]]; then
        echo -e "\033[0;31m[ERROR]\033[0m Issue file path is required." >&2
        echo "Usage: post-skill-issue.sh <path-to-issue-file.md>" >&2
        return 2
    fi

    if [[ ! -f "$issue_path" ]]; then
        echo -e "\033[0;31m[ERROR]\033[0m Issue file not found: ${issue_path}" >&2
        return 2
    fi

    local file_content
    file_content=$(cat "$issue_path")

    # --- Parse frontmatter ---
    local issue_id device platform category tags
    issue_id=$(_fm_field "id" "$file_content")
    device=$(_fm_field "device" "$file_content")
    platform=$(_fm_field "platform" "$file_content")
    category=$(_fm_field "category" "$file_content")
    tags=$(_fm_field "tags" "$file_content")

    # Validate we have at least an id
    if [[ -z "$issue_id" ]]; then
        echo -e "\033[0;31m[ERROR]\033[0m Could not parse issue ID from frontmatter: ${issue_path}" >&2
        return 2
    fi

    # --- Extract body sections ---
    local context_text symptoms_text
    context_text=$(_section "Context" "$file_content")
    symptoms_text=$(_section "Symptoms" "$file_content")

    # Fall back to Problem/Description section if Context is empty (older issue format)
    if [[ -z "$context_text" ]]; then
        context_text=$(_section "Problem" "$file_content")
    fi
    if [[ -z "$context_text" ]]; then
        context_text=$(_section "Description" "$file_content")
    fi

    # Default if still empty
    [[ -z "$context_text" ]] && context_text="(No context section found — see local issue file)"
    [[ -z "$symptoms_text" ]] && symptoms_text="(No symptoms section found — see local issue file)"

    # --- Detect component, affected file, platform ---
    local full_text="${file_content}"
    local component affected_file platform_label component_name

    component=$(_detect_component_type "$full_text")
    affected_file=$(_detect_affected_file "$full_text")
    platform_label=$(_detect_platform_label "$platform" "$full_text")

    # Derive component name from affected file basename
    if [[ "$affected_file" != "(see issue body)" ]]; then
        component_name=$(basename "$affected_file")
    else
        component_name="$issue_id"
    fi

    # --- Build GitHub issue title ---
    local title
    # Try to get title from frontmatter
    title=$(_fm_field "title" "$file_content")
    if [[ -z "$title" ]]; then
        # Try first markdown H1
        title=$(echo "$file_content" | grep "^# " | head -1 | sed 's/^# //')
    fi
    if [[ -z "$title" ]]; then
        title="Skill bug: ${issue_id}"
    fi
    # Prefix with [skill-bug] if not already tagged
    if ! echo "$title" | grep -qi "skill.bug\|skill bug"; then
        title="[skill-bug] ${title}"
    fi

    # --- Check for gh CLI availability ---
    if ! command -v gh &>/dev/null; then
        _fallback_no_gh "$issue_path" "gh not found in PATH"
        return 0
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        _fallback_no_gh "$issue_path" "gh not authenticated (run: gh auth login)"
        return 0
    fi

    # --- Duplicate check ---
    echo -e "\033[0;36m[INFO]\033[0m Checking for duplicate issues on ${GITHUB_REPO}..."
    local existing_issues
    existing_issues=$(gh issue list \
        --repo "$GITHUB_REPO" \
        --label "skill-bug" \
        --state open \
        --json number,title \
        --jq '.[].title' 2>/dev/null || echo "")

    # Check by issue ID (exact) or component name (fuzzy)
    if echo "$existing_issues" | grep -qF "$issue_id"; then
        echo -e "\033[1;33m[WARN]\033[0m Duplicate found — issue ${issue_id} is already posted on GitHub."
        echo "Skipping escalation."
        log_admin_event "Skill issue already on GitHub (duplicate): ${issue_id}" "INFO"
        return 0
    fi

    if [[ "$component_name" != "$issue_id" ]] && echo "$existing_issues" | grep -qF "$component_name"; then
        echo -e "\033[1;33m[WARN]\033[0m A similar issue for '${component_name}' already exists on GitHub:"
        echo "$existing_issues" | grep -F "$component_name"
        echo ""
        echo -n "Post anyway? (y/N): "
        local confirm
        IFS= read -r confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Skipping."
            return 0
        fi
    fi

    # --- Build issue body ---
    local body
    body=$(cat <<BODY
## Skill Bug Report

**Local Issue ID:** \`${issue_id}\`
**Device:** ${device}
**Platform:** ${platform}
**Affected Component:** ${component}: \`${component_name}\`
**Affected File:** \`${affected_file}\`

## Context
${context_text}

## Symptoms
${symptoms_text}

---
*Full investigation record in local issue file \`${issue_id}\`. This issue was auto-generated by the admin-devops escalation workflow.*
BODY
)

    # --- Build label list ---
    local labels="skill-bug,${component},${platform_label},needs-triage"

    # --- Display summary and confirm ---
    echo ""
    echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;37m  Skill Bug Escalation\033[0m"
    echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo "  Repo:       ${GITHUB_REPO}"
    echo "  Title:      ${title}"
    echo "  Component:  ${component}: ${component_name}"
    echo "  Platform:   ${platform_label}"
    echo "  Labels:     ${labels}"
    echo "  Local ID:   ${issue_id}"
    echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -n "Post to GitHub Issues on ${GITHUB_REPO}? (y/N): "

    local confirm
    IFS= read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Escalation cancelled. Issue remains local."
        log_admin_event "Skill issue escalation declined by operator: ${issue_id}" "INFO"
        return 0
    fi

    # --- Post to GitHub ---
    echo -e "\033[0;36m[INFO]\033[0m Posting to ${GITHUB_REPO}..."

    local issue_url
    issue_url=$(gh issue create \
        --repo "$GITHUB_REPO" \
        --title "$title" \
        --body "$body" \
        --label "$labels" 2>&1)

    # gh issue create returns the URL on success
    if echo "$issue_url" | grep -qE '^https://github.com/'; then
        echo -e "\033[0;32m[OK]\033[0m Issue posted: ${issue_url}"

        # --- Update local issue file ---
        _update_fm_field "github_issue_url" "$issue_url" "$issue_path"
        # Update status timestamp
        local iso_timestamp
        iso_timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
        sed -i "s/^updated:.*/updated: ${iso_timestamp}/" "$issue_path"

        log_admin_event "Skill issue escalated to GitHub: ${issue_id} → ${issue_url}" "OK"
        echo -e "\033[0;32m[OK]\033[0m Local issue updated with GitHub URL."
    else
        echo -e "\033[0;31m[ERROR]\033[0m gh issue create failed:" >&2
        echo "$issue_url" >&2
        _fallback_no_gh "$issue_path" "gh issue create returned unexpected output"
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Entry point — direct execution
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" && -n "${0:-}" ]]; then
    if [[ $# -eq 1 ]]; then
        post_skill_issue "$1"
    else
        echo "Usage: post-skill-issue.sh <path-to-local-issue-file.md>"
        echo ""
        echo "Escalates a local ~/.admin/issues/ file to a GitHub Issue on evolv3-ai/vibe-skills."
        echo "Only for skill-level bugs requiring code changes. Requires operator confirmation."
        echo ""
        echo "Examples:"
        echo "  post-skill-issue.sh ~/.admin/issues/issue_20260401_120000_bad_flag.md"
        echo "  post-skill-issue.sh \"\$(ls ~/.admin/issues/*.md | tail -1)\""
        exit 2
    fi
fi
