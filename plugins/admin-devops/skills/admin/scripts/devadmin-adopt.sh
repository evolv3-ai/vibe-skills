#!/usr/bin/env bash
# =============================================================================
# devadmin-adopt.sh — read-only shape detection for /admin-devops:adopt-devadmin
# =============================================================================
# Detects the local (filesystem + profile + local-issue) half of a host's
# devadmin adoption state. The Linear half (project/label/seat/ledger) is checked
# by the command via MCP — this script never touches the network and never mutates.
#
# Bash side covers WSL / Linux / macOS seats (workspace ~/dev/devadmin).
# The PowerShell sibling (devadmin-adopt.ps1) covers Windows-native seats (D:\devadmin).
#
# Output: a single JSON object on stdout describing what is in place vs missing,
# plus a `placeholders` object the command uses to instantiate the CLAUDE.md
# template. Read-only: no writes, no deletes, no network.
#
# Usage:
#   ./devadmin-adopt.sh                 # detect, print JSON
#   ./devadmin-adopt.sh --pretty        # re-validate through jq when available
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
SKILL_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)          # .../skills/admin
TEMPLATE_DIR="${SKILL_ROOT}/assets/devadmin"
SATELLITE_ENV="${HOME}/.admin/.env"
PRETTY=0
[[ "${1:-}" == "--pretty" ]] && PRETTY=1
emit() { if [[ $PRETTY -eq 1 ]] && command -v jq >/dev/null 2>&1; then jq .; else cat; fi; }

# --- helpers ----------------------------------------------------------------

read_env_var() {  # $1 var, $2 file
    grep "^${1}=" "${2}" 2>/dev/null | head -1 | cut -d'=' -f2- || true
}

json_escape() {   # escape a string for embedding in JSON
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# Map a device name to the short host slug used by the routing map / host:* labels.
host_slug() {
    local dev_lc
    dev_lc=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$dev_lc" in
        wopr3*)              echo "wopr3" ;;
        delta*|deltabot*)    echo "delta" ;;
        casa*|casaten*)      echo "casa" ;;
        *)                   printf '%s' "$dev_lc" | tr -cd 'a-z0-9' ;;
    esac
}

# --- resolve profile (read-only) -------------------------------------------

ADMIN_ROOT_R="${ADMIN_ROOT:-}"
DEVICE_R="${ADMIN_DEVICE:-}"
PLATFORM_R="${ADMIN_PLATFORM:-}"
if [[ -f "$SATELLITE_ENV" ]]; then
    [[ -z "$ADMIN_ROOT_R" ]] && ADMIN_ROOT_R=$(read_env_var ADMIN_ROOT "$SATELLITE_ENV")
    [[ -z "$DEVICE_R"     ]] && DEVICE_R=$(read_env_var ADMIN_DEVICE "$SATELLITE_ENV")
    [[ -z "$PLATFORM_R"   ]] && PLATFORM_R=$(read_env_var ADMIN_PLATFORM "$SATELLITE_ENV")
fi
ADMIN_ROOT_R="${ADMIN_ROOT_R:-${HOME}/.admin}"
DEVICE_R="${DEVICE_R:-$(hostname)}"
if [[ -z "$PLATFORM_R" ]]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then PLATFORM_R="wsl"
    elif [[ "$(uname -s)" == "Darwin" ]]; then PLATFORM_R="macos"
    else PLATFORM_R="linux"; fi
fi
PROFILE_PATH="${ADMIN_ROOT_R}/profiles/${DEVICE_R}.json"
PROFILE_EXISTS="false"; [[ -f "$PROFILE_PATH" ]] && PROFILE_EXISTS="true"

SLUG=$(host_slug "$DEVICE_R")
HOST_LABEL="host:${SLUG}"
ISSUES_DIR="${ADMIN_ROOT_R}/issues"

# Template + workspace selection. Bash side is always the "wsl" template family.
TEMPLATE_KIND="wsl"
TEMPLATE_FILE="${TEMPLATE_DIR}/CLAUDE.md.${TEMPLATE_KIND}.template"
WORKSPACE="${HOME}/dev/devadmin"
if [[ "$PLATFORM_R" == "wsl" ]]; then
    SUGGESTED_CODE="${SLUG}-claude-cli-wsl"
else
    SUGGESTED_CODE="${SLUG}-claude-cli"   # bare linux/macos native seat
    TEMPLATE_KIND="native"
    TEMPLATE_FILE="${TEMPLATE_DIR}/CLAUDE.md.native.template"
fi

# --- workspace + CLAUDE.md shape -------------------------------------------

WS_EXISTS="false";  [[ -d "$WORKSPACE" ]] && WS_EXISTS="true"
WS_CLAUDE="${WORKSPACE}/CLAUDE.md"
WS_CLAUDE_EXISTS="false"; [[ -f "$WS_CLAUDE" ]] && WS_CLAUDE_EXISTS="true"

TEMPLATE_SHAPE=$(grep -oE 'Template shape version: [0-9]+' "$TEMPLATE_FILE" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
TEMPLATE_SHAPE="${TEMPLATE_SHAPE:-unknown}"
WS_SHAPE=""
WS_SHAPE_STALE="unknown"
if [[ "$WS_CLAUDE_EXISTS" == "true" ]]; then
    WS_SHAPE=$(grep -oE 'Template shape version: [0-9]+' "$WS_CLAUDE" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
    if [[ -z "$WS_SHAPE" ]]; then WS_SHAPE_STALE="true"     # no version marker = pre-template shape
    elif [[ "$WS_SHAPE" == "$TEMPLATE_SHAPE" ]]; then WS_SHAPE_STALE="false"
    else WS_SHAPE_STALE="true"; fi
fi

# --- retired-path scan (read-only) -----------------------------------------
# Candidate older shapes for this seat. Windows-side paths are checked under
# /mnt/d when this is a WSL seat that can see the Windows drive.
RETIRED_CANDIDATES=(
    "${HOME}/dev/admin-wsl"
    "${HOME}/wsl-admin"
    "${HOME}/dev/admin-native"
    "${HOME}/dev/devops-native"
    "/mnt/d/admin-native"
    "/mnt/d/devops-native"
    "/mnt/d/admin"
    "/mnt/d/_admin"
    "/mnt/d/admin-test"
)
RETIRED_FOUND=()
for p in "${RETIRED_CANDIDATES[@]}"; do
    [[ -e "$p" ]] && RETIRED_FOUND+=("$p")
done
# globbed throwaway test dirs
for g in "${HOME}/dev/"admin-test*; do
    [[ -e "$g" ]] && RETIRED_FOUND+=("$g")
done

# --- local issue census -----------------------------------------------------
# Supports both the /troubleshoot naming (issue_YYYYMMDD_*.md) and the
# devadmin ISSUE-00xx.md convention. Counts open vs resolved by frontmatter status.
ISSUES_TOTAL=0; ISSUES_OPEN=0; ISSUES_RESOLVED=0
if [[ -d "$ISSUES_DIR" ]]; then
    while IFS= read -r -d '' f; do
        ISSUES_TOTAL=$((ISSUES_TOTAL + 1))
        st=$(grep -m1 -E '^status:' "$f" 2>/dev/null | sed -E 's/^status:[[:space:]]*//' | tr -d '[:space:]' || true)
        case "$st" in
            resolved|closed|done) ISSUES_RESOLVED=$((ISSUES_RESOLVED + 1)) ;;
            *)                    ISSUES_OPEN=$((ISSUES_OPEN + 1)) ;;
        esac
    done < <(find "$ISSUES_DIR" -maxdepth 1 -type f \( -iname 'ISSUE-*.md' -o -iname 'issue_*.md' \) -print0 2>/dev/null)
fi

# --- assemble JSON ----------------------------------------------------------

retired_json="["
first=1
for p in "${RETIRED_FOUND[@]}"; do
    [[ $first -eq 0 ]] && retired_json+=","
    retired_json+="\"$(json_escape "$p")\""
    first=0
done
retired_json+="]"

GEN_DATE=$(date +%Y-%m-%d 2>/dev/null || echo "")

emit <<JSON
{
  "host": "$(json_escape "$DEVICE_R")",
  "hostSlug": "$(json_escape "$SLUG")",
  "hostLabel": "$(json_escape "$HOST_LABEL")",
  "platform": "$(json_escape "$PLATFORM_R")",
  "suggestedAgentCode": "$(json_escape "$SUGGESTED_CODE")",
  "profile": { "exists": ${PROFILE_EXISTS}, "path": "$(json_escape "$PROFILE_PATH")", "adminRoot": "$(json_escape "$ADMIN_ROOT_R")" },
  "workspace": {
    "path": "$(json_escape "$WORKSPACE")",
    "exists": ${WS_EXISTS},
    "claudeMd": { "exists": ${WS_CLAUDE_EXISTS}, "shapeVersion": "$(json_escape "$WS_SHAPE")", "stale": "$(json_escape "$WS_SHAPE_STALE")" }
  },
  "template": { "kind": "$(json_escape "$TEMPLATE_KIND")", "file": "$(json_escape "$TEMPLATE_FILE")", "shapeVersion": "$(json_escape "$TEMPLATE_SHAPE")" },
  "retiredPaths": ${retired_json},
  "localIssues": { "dir": "$(json_escape "$ISSUES_DIR")", "total": ${ISSUES_TOTAL}, "open": ${ISSUES_OPEN}, "resolved": ${ISSUES_RESOLVED} },
  "placeholders": {
    "HOST": "$(json_escape "$DEVICE_R")",
    "HOST_SLUG": "$(json_escape "$SLUG")",
    "HOST_LABEL": "$(json_escape "$HOST_LABEL")",
    "AGENT_CODE": "$(json_escape "$SUGGESTED_CODE")",
    "PLATFORM": "$(json_escape "$PLATFORM_R")",
    "WORKSPACE_PATH": "$(json_escape "$WORKSPACE")",
    "ADMIN_ROOT": "$(json_escape "$ADMIN_ROOT_R")",
    "LOCAL_ISSUES_DIR": "$(json_escape "$ISSUES_DIR")",
    "GENERATED": "$(json_escape "$GEN_DATE")"
  }
}
JSON
