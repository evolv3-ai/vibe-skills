#!/usr/bin/env bash
# =============================================================================
# Migrate Secrets Phase 4 - Deployment secrets to admin-runtime
# =============================================================================
# Moves deployment-specific secrets (KASM admin passwords, CF tokens) into
# admin-runtime/deployments/{deployment-id}/ folders.
# Updates profile deployments{} entries with secretRefs.
#
# Idempotent: checks before writing.
#
# Usage:
#   ./migrate-secrets-phase4.sh [--dry-run] [--env ENV]
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

resolve_device_name() {
    if [[ -n "${ADMIN_DEVICE:-}" ]]; then echo "$ADMIN_DEVICE"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local dev
        dev=$(grep "^ADMIN_DEVICE=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [[ -n "$dev" ]]; then echo "$dev"; return; fi
    fi
    hostname
}

ADMIN_ROOT="$(resolve_admin_root)"
DEVICE_NAME="$(resolve_device_name)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="${ADMIN_ROOT}/config/infisical-projects.json"
PROFILE_PATH="${ADMIN_ROOT}/profiles/${DEVICE_NAME}.json"

DRY_RUN=false
ENV_SLUG="prod"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --env) ENV_SLUG="$2"; shift 2 ;;
        -h|--help) echo "Usage: migrate-secrets-phase4.sh [--dry-run] [--env ENV]"; exit 0 ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then err "jq required"; exit 1; fi
if [[ ! -f "$PROJECTS_FILE" ]]; then err "Projects config not found"; exit 1; fi

PROJECT_ID=$(jq -r '.projects["admin-runtime"].id // empty' "$PROJECTS_FILE")
if [[ -z "$PROJECT_ID" ]]; then err "admin-runtime project ID not set"; exit 1; fi

section "Phase 4: Migrate Deployment Secrets"
info "Project ID: $PROJECT_ID"

# Deployment secret mappings: deployment_id:flat_key:target_key
DEPLOY_SECRETS=(
    "kasm-contabo-01:KASM_CONTABO_01_ADMIN_PASSWORD:ADMIN_PASSWORD"
    "kasm-contabo-01:KASM_CONTABO_01_CF_TOKEN:CF_TUNNEL_TOKEN"
    "kasm-hetzner-01:KASM_HETZNER_01_ADMIN_PASSWORD:ADMIN_PASSWORD"
    "kasm-hetzner-01:KASM_HETZNER_01_CF_TOKEN:CF_TUNNEL_TOKEN"
    "kasm-hetzner-02:KASM_HETZNER_02_ADMIN_PASSWORD:ADMIN_PASSWORD"
    "kasm-hetzner-02:KASM_HETZNER_02_CF_TOKEN:CF_TUNNEL_TOKEN"
    "nanoclaw-contabo-01:NANOCLAW_CONTABO_01_CF_TOKEN:CF_TUNNEL_TOKEN"
)

get_current_value() {
    local key="$1"
    "$SCRIPT_DIR/secrets" "$key" 2>/dev/null || true
}

migrated=0
skipped=0
failed=0

for entry in "${DEPLOY_SECRETS[@]}"; do
    IFS=':' read -r deploy_id flat_key target_key <<< "$entry"
    target_path="/deployments/$deploy_id"

    echo -n "  $flat_key -> $target_path/$target_key... "

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN]"
        migrated=$((migrated + 1))
        continue
    fi

    value=$(get_current_value "$flat_key")
    if [[ -z "$value" ]]; then
        echo "SKIP (not found)"
        skipped=$((skipped + 1))
        continue
    fi

    existing=$(infisical secrets get "$target_key" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "$target_path" --plain 2>/dev/null || true)
    if [[ -n "$existing" ]]; then
        echo "EXISTS"
        skipped=$((skipped + 1))
        continue
    fi

    if infisical secrets set "${target_key}=${value}" --projectId "$PROJECT_ID" --env "$ENV_SLUG" --path "$target_path" >/dev/null 2>&1; then
        echo "OK"
        migrated=$((migrated + 1))
    else
        echo "FAILED"
        failed=$((failed + 1))
    fi
done

# --- Update profile deployments with secretRefs ---
if [[ -f "$PROFILE_PATH" && "$DRY_RUN" != "true" ]]; then
    section "Updating Profile: deployment secretRefs"

    jq --arg env "$ENV_SLUG" '
    .deployments |= with_entries(
        if .key | test("kasm-contabo-01|kasm-hetzner-01|kasm-hetzner-02|nanoclaw-contabo-01") then
            .value.secretRefs = {
                "admin_password": ("infisical://admin-runtime/" + $env + "/deployments/" + .key + "/ADMIN_PASSWORD"),
                "cf_tunnel_token": ("infisical://admin-runtime/" + $env + "/deployments/" + .key + "/CF_TUNNEL_TOKEN")
            }
        else . end
    )
    ' "$PROFILE_PATH" > "${PROFILE_PATH}.tmp" && mv "${PROFILE_PATH}.tmp" "$PROFILE_PATH"
    ok "Profile deployments updated with secretRefs"
fi

section "Phase 4 Summary"
echo "Migrated: $migrated  Skipped: $skipped  Failed: $failed"
