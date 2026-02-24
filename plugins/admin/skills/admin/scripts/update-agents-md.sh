#!/usr/bin/env bash
# =============================================================================
# Regenerate AGENTS.md from template
# =============================================================================
# Copies the AGENTS.md template to ADMIN_ROOT/AGENTS.md.
# Run this after updating the template or to refresh the file.
#
# Usage:
#   ./update-agents-md.sh
# =============================================================================

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
SKILL_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# Source logging helper
source "${SCRIPT_DIR}/log-admin-event.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Resolve ADMIN_ROOT from satellite .env or environment
if [[ -n "${ADMIN_ROOT:-}" ]]; then
    admin_root="$ADMIN_ROOT"
elif [[ -f "${HOME}/.admin/.env" ]]; then
    admin_root=$(grep "^ADMIN_ROOT=" "${HOME}/.admin/.env" 2>/dev/null | head -1 | cut -d'=' -f2-)
    admin_root="${admin_root:-${HOME}/.admin}"
else
    admin_root="${HOME}/.admin"
fi

if [[ ! -d "$admin_root" ]]; then
    echo -e "${RED}[ERROR]${NC} ADMIN_ROOT not found: $admin_root"
    echo "Run setup-interview.sh first to create the admin structure."
    exit 1
fi

# Copy template
agents_md_template="${SKILL_ROOT}/templates/AGENTS.md"
agents_md_path="${admin_root}/AGENTS.md"

if [[ ! -f "$agents_md_template" ]]; then
    echo -e "${RED}[ERROR]${NC} Template not found: $agents_md_template"
    exit 1
fi

cp "$agents_md_template" "$agents_md_path"
log_ok "AGENTS.md updated: $agents_md_path"

log_admin_event "AGENTS.md regenerated" "INFO" > /dev/null 2>&1 || true
