#!/usr/bin/env bash
# =============================================================================
# Admin Suite Issue Updater - Bash version for WSL/Unix
# =============================================================================
# Usage:
#   source update-admin-issue.sh
#   update_admin_issue "issue_20260201_audio" "resolution" "Reinstalled driver"
#   update_admin_issue "issue_20260201_audio" --resolve
# Or run directly:
#   ./update-admin-issue.sh "issue_20260201_audio" "resolution" "Fixed"
#   ./update-admin-issue.sh "issue_20260201_audio" --resolve
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)

# Source the logging function
# shellcheck source=log-admin-event.sh
source "${SCRIPT_DIR}/log-admin-event.sh"

# Resolve ADMIN_ROOT from satellite .env or environment
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

update_admin_issue() {
    local issue_id="$1"
    local section_or_flag="${2:-}"
    local content="${3:-}"
    local resolve=false

    if [[ -z "$issue_id" ]]; then
        echo -e "\033[0;31m[ERROR]\033[0m Issue ID is required" >&2
        return 1
    fi

    # Check for --resolve flag
    if [[ "$section_or_flag" == "--resolve" ]]; then
        resolve=true
        section_or_flag=""
    fi

    # Resolve ADMIN_ROOT
    local admin_root
    admin_root=$(_resolve_admin_root)

    # Find issue file
    local issues_dir="${admin_root}/issues"
    local issue_file="${issues_dir}/${issue_id}.md"

    if [[ ! -f "$issue_file" ]]; then
        # Try partial match
        local matches
        matches=$(find "$issues_dir" -maxdepth 1 -name "*${issue_id}*.md" 2>/dev/null || true)
        local match_count
        match_count=$(echo -n "$matches" | grep -c . || echo 0)

        if [[ "$match_count" -eq 1 ]]; then
            issue_file="$matches"
            issue_id=$(basename "$issue_file" .md)
        elif [[ "$match_count" -gt 1 ]]; then
            echo -e "\033[0;31m[ERROR]\033[0m Multiple matches found for '$issue_id':" >&2
            echo "$matches" | while read -r f; do basename "$f" .md; done >&2
            return 1
        else
            echo -e "\033[0;31m[ERROR]\033[0m Issue not found: $issue_id" >&2
            return 1
        fi
    fi

    # Read current content
    local file_content
    file_content=$(cat "$issue_file")

    # Update timestamp in frontmatter
    local iso_timestamp
    iso_timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
    file_content=$(echo "$file_content" | sed "s/^updated:.*$/updated: $iso_timestamp/")

    # Update section if specified
    if [[ -n "$section_or_flag" && -n "$content" ]]; then
        local section_header
        case "$section_or_flag" in
            context)      section_header="## Context" ;;
            symptoms)     section_header="## Symptoms" ;;
            hypotheses)   section_header="## Hypotheses" ;;
            actions)      section_header="## Actions Taken" ;;
            resolution)   section_header="## Resolution" ;;
            verification) section_header="## Verification" ;;
            nextaction)   section_header="## Next Action" ;;
            *)
                echo -e "\033[0;31m[ERROR]\033[0m Invalid section: $section_or_flag" >&2
                echo "Valid sections: context, symptoms, hypotheses, actions, resolution, verification, nextaction" >&2
                return 1
                ;;
        esac

        # Use awk to insert content after section header
        file_content=$(echo "$file_content" | awk -v header="$section_header" -v content="$content" '
            BEGIN { found = 0; printed = 0 }
            $0 == header {
                print;
                found = 1;
                next
            }
            found == 1 && /^## / {
                if (!printed) {
                    print "";
                    print content;
                    print "";
                    printed = 1;
                }
                found = 0;
                print;
                next
            }
            found == 1 && /^$/ && !printed {
                print "";
                print content;
                printed = 1;
                next
            }
            { print }
            END {
                if (found == 1 && !printed) {
                    print "";
                    print content;
                }
            }
        ')
    fi

    # Update status if resolving
    if [[ "$resolve" == true ]]; then
        file_content=$(echo "$file_content" | sed 's/^status: open$/status: resolved/')
        log_admin_event "Issue resolved: $issue_id" "OK"
        echo -e "\033[0;32m[OK]\033[0m Issue resolved: $issue_id"
    else
        if [[ -n "$section_or_flag" ]]; then
            log_admin_event "Issue updated: $issue_id (section: $section_or_flag)" "INFO"
        fi
        echo -e "\033[0;32m[OK]\033[0m Issue updated: $issue_id"
    fi

    # Write updated content
    echo "$file_content" > "$issue_file"

    echo "$issue_file"
}

# If script is run directly (not sourced), execute with arguments
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" && -n "${0:-}" ]]; then
    if [[ $# -ge 1 ]]; then
        update_admin_issue "$@"
    else
        echo "Usage: update-admin-issue.sh <issue_id> [section] [content]"
        echo "       update-admin-issue.sh <issue_id> --resolve"
        echo ""
        echo "  section: context, symptoms, hypotheses, actions, resolution, verification, nextaction"
        exit 1
    fi
fi
