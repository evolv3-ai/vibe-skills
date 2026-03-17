#!/usr/bin/env bash
# =============================================================================
# Migrate Secrets Phase 2 - Move shared operator secrets to admin-operator
# =============================================================================
# Reads secrets from current flat backend (vault/infisical), writes to
# admin-operator project with folder paths.
#
# Idempotent: checks if target secret exists before writing.
#
# Usage:
#   ./migrate-secrets-phase2.sh              # Migrate all operator secrets
#   ./migrate-secrets-phase2.sh --dry-run    # Show what would be migrated
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[i]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

SATELLITE_ENV="${HOME}/.admin/.env"

resolve_admin_root() {
    if [[ -n "${ADMIN_ROOT:-}" ]]; then echo "$ADMIN_ROOT"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local root
        root=$(grep "^ADMIN_ROOT=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$root" ]]; then echo "$root"; return; fi
    fi
    echo "${HOME}/.admin"
}

ADMIN_ROOT="$(resolve_admin_root)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="${ADMIN_ROOT}/config/infisical-projects.json"

DRY_RUN=false
ENV_SLUG="prod"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --env) ENV_SLUG="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: migrate-secrets-phase2.sh [--dry-run] [--env ENV]"
            exit 0
            ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

# Resolve project ID
if ! command -v jq &>/dev/null; then err "jq required"; exit 1; fi
if [[ ! -f "$PROJECTS_FILE" ]]; then err "Projects config not found: $PROJECTS_FILE"; exit 1; fi

PROJECT_ID=$(jq -r '.projects["admin-operator"].id // empty' "$PROJECTS_FILE")
if [[ -z "$PROJECT_ID" ]]; then
    err "admin-operator project ID not set in $PROJECTS_FILE"
    exit 1
fi

section "Phase 2: Migrate Operator Secrets to admin-operator"
info "Project ID: $PROJECT_ID"
info "Environment: $ENV_SLUG"

# Secret mapping: FLAT_KEY -> FOLDER/NEW_KEY
declare -A SECRET_MAP
SECRET_MAP=(
    ["HCLOUD_TOKEN"]="/providers/hetzner/HCLOUD_TOKEN"
    ["CNTB_OAUTH2_CLIENT_SECRET"]="/providers/contabo/CLIENT_SECRET"
    ["CNTB_OAUTH2_PASS"]="/providers/contabo/OAUTH_PASS"
    ["CF_API_TOKEN"]="/network/cloudflare/API_TOKEN"
    ["CF_ZONE_ID"]="/network/cloudflare/ZONE_ID"
    ["CF_ACCOUNT_ID"]="/network/cloudflare/ACCOUNT_ID"
    ["OPENROUTER_API_KEY"]="/shared/llm/OPENROUTER_API_KEY"
    ["OPENAI_API_KEY"]="/shared/llm/OPENAI_API_KEY"
    ["MM_ADMIN_TOKEN"]="/shared/mattermost/ADMIN_TOKEN"
    ["MM_URL"]="/shared/mattermost/URL"
    ["SENTINEL_TOKEN"]="/shared/sentinel/TOKEN"
    ["LINODE_API_TOKEN"]="/providers/linode/API_TOKEN"
    ["DIGITALOCEAN_ACCESS_TOKEN"]="/providers/digitalocean/ACCESS_TOKEN"
    ["VULTR_API_KEY"]="/providers/vultr/API_KEY"
    ["GITHUB_TOKEN"]="/shared/GITHUB_TOKEN"
)

# Get current secrets from flat backend
get_current_value() {
    local key="$1"
    "$SCRIPT_DIR/secrets" "$key" 2>/dev/null || true
}

migrated=0
skipped=0
failed=0

for flat_key in "${!SECRET_MAP[@]}"; do
    target="${SECRET_MAP[$flat_key]}"
    # Split target into path and key
    target_path=$(dirname "$target")
    target_key=$(basename "$target")

    echo -n "  $flat_key -> $target... "

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN]"
        migrated=$((migrated + 1))
        continue
    fi

    # Get current value
    value=$(get_current_value "$flat_key")
    if [[ -z "$value" ]]; then
        echo "SKIP (not found in current backend)"
        skipped=$((skipped + 1))
        continue
    fi

    # Check if target already exists
    existing=$(infisical secrets get "$target_key" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "$target_path" --plain 2>/dev/null || true)
    if [[ -n "$existing" ]]; then
        echo "EXISTS (skipped)"
        skipped=$((skipped + 1))
        continue
    fi

    # Write to target
    if infisical secrets set "${target_key}=${value}" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "$target_path" >/dev/null 2>&1; then
        echo "OK"
        migrated=$((migrated + 1))
    else
        echo "FAILED"
        failed=$((failed + 1))
    fi
done

section "Phase 2 Summary"
echo "Migrated: $migrated"
echo "Skipped:  $skipped"
echo "Failed:   $failed"

if [[ "$DRY_RUN" == "true" ]]; then
    warn "This was a dry run. No secrets were moved."
fi

echo ""
echo "Next: Run migrate-secrets-phase3.sh for agent runtime secrets"
