#!/bin/bash
# =============================================================================
# Migrate plaintext .env to age-encrypted vault
# =============================================================================
# Usage: migrate-to-vault.sh [SOURCE_ENV]
#
# If no SOURCE_ENV given, uses $ADMIN_ROOT/.env
# Creates vault at $ADMIN_ROOT/vault.age
# Optionally enables ADMIN_VAULT=enabled in satellite .env
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SATELLITE_ENV="${HOME}/.admin/.env"

# Resolve ADMIN_ROOT
if [[ -n "${ADMIN_ROOT:-}" ]]; then
    :
elif [[ -f "$SATELLITE_ENV" ]]; then
    ADMIN_ROOT=$(grep "^ADMIN_ROOT=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
fi
ADMIN_ROOT="${ADMIN_ROOT:-${HOME}/.admin}"

# Resolve AGE_KEY from satellite .env or default
if [[ -n "${AGE_KEY_PATH:-}" ]]; then
    AGE_KEY="$AGE_KEY_PATH"
elif [[ -f "$SATELLITE_ENV" ]]; then
    AGE_KEY=$(grep "^AGE_KEY_PATH=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2-)
fi
AGE_KEY="${AGE_KEY:-${HOME}/.age/key.txt}"

SOURCE_ENV="${1:-${ADMIN_ROOT}/.env}"
VAULT_FILE="${ADMIN_ROOT}/vault.age"

echo ""
echo -e "${CYAN}=== Admin Vault Migration ===${NC}"
echo "Source:  $SOURCE_ENV"
echo "Vault:   $VAULT_FILE"
echo "Key:     $AGE_KEY"
echo ""

# --- Step 1: Check prerequisites ---
log_info "Checking prerequisites..."

if ! command -v age &> /dev/null; then
    log_error "age not installed. Install: sudo apt install age (Linux) / brew install age (macOS)"
    exit 1
fi
log_ok "age CLI available ($(age --version))"

# --- Step 2: Generate key if needed ---
if [[ ! -f "$AGE_KEY" ]]; then
    log_info "No age key found. Generating..."
    mkdir -p "$(dirname "$AGE_KEY")"
    age-keygen -o "$AGE_KEY" 2>&1
    chmod 600 "$AGE_KEY"
    log_ok "Key generated at $AGE_KEY"
    echo ""
    log_warn "IMPORTANT: Back up this key! Without it, vault cannot be decrypted."
    log_warn "Store a copy somewhere safe (password manager, printed, USB)."
    echo ""
else
    log_ok "Age key exists at $AGE_KEY"
fi

# --- Step 3: Verify source .env ---
if [[ ! -f "$SOURCE_ENV" ]]; then
    log_error "Source file not found: $SOURCE_ENV"
    log_info "Create your .env first, or specify path: migrate-to-vault.sh /path/to/.env"
    exit 1
fi

SECRET_COUNT=$(grep -c '=' "$SOURCE_ENV" 2>/dev/null || echo 0)
log_ok "Source file: $SOURCE_ENV ($SECRET_COUNT entries)"

# --- Step 4: Encrypt ---
log_info "Encrypting to vault..."

PUBLIC_KEY=$(age-keygen -y "$AGE_KEY")
age -e -r "$PUBLIC_KEY" -a -o "$VAULT_FILE" "$SOURCE_ENV"
chmod 600 "$VAULT_FILE"

log_ok "Vault created: $VAULT_FILE"

# --- Step 5: Verify round-trip ---
log_info "Verifying round-trip integrity..."

DIFF_OUTPUT=$(diff <(age -d -i "$AGE_KEY" "$VAULT_FILE" 2>/dev/null) "$SOURCE_ENV" 2>&1 || true)

if [[ -z "$DIFF_OUTPUT" ]]; then
    log_ok "Round-trip verification PASSED (decrypt matches original)"
else
    log_error "Round-trip verification FAILED!"
    echo "$DIFF_OUTPUT"
    log_warn "Vault may be corrupted. Source .env NOT deleted."
    exit 1
fi

# --- Step 6: Enable vault in satellite .env ---
echo ""
if [[ -f "$SATELLITE_ENV" ]]; then
    CURRENT_MODE=$(grep "^ADMIN_VAULT=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "")
    if [[ "$CURRENT_MODE" == "enabled" ]]; then
        log_ok "ADMIN_VAULT=enabled already set in satellite .env"
    else
        read -rp "Enable vault in satellite .env? (ADMIN_VAULT=enabled) [y/N] " ENABLE
        if [[ "${ENABLE,,}" == "y" ]]; then
            if grep -q "^ADMIN_VAULT=" "$SATELLITE_ENV" 2>/dev/null; then
                sed -i "s/^ADMIN_VAULT=.*/ADMIN_VAULT=enabled/" "$SATELLITE_ENV"
            else
                echo "ADMIN_VAULT=enabled" >> "$SATELLITE_ENV"
            fi
            log_ok "ADMIN_VAULT=enabled set in $SATELLITE_ENV"
        else
            log_info "Skipped. Enable later: echo 'ADMIN_VAULT=enabled' >> $SATELLITE_ENV"
        fi
    fi
fi

# --- Step 7: Generate manifest .env ---
# Instead of deleting the plaintext, replace it with a manifest that shows
# all keys but keeps secret values empty (with "# in vault" comment).
# Non-secret values (bootstrap vars) remain populated.
echo ""
log_info "Generating manifest .env (keys visible, secrets in vault)..."

# Known non-secret keys that should keep their values
NON_SECRET_KEYS="ADMIN_ROOT ADMIN_DEVICE ADMIN_PLATFORM ADMIN_VAULT AGE_KEY_PATH ADMIN_SYNC_ENABLED ADMIN_SYNC_PATH ADMIN_LOG_PATH ADMIN_PROFILE_PATH ADMIN_USER DEVICE_NAME WIN_USER_HOME WIN_ADMIN_PATH WSL_ADMIN_PATH WSL_DISTRO SSH_KEY_PATH SSH_PUBLIC_KEY_PATH SSH_CONFIG_PATH OCI_CONFIG_PATH OCI_REGION HCLOUD_CONTEXT COOLIFY_DOMAIN COOLIFY_ADMIN_EMAIL COOLIFY_WILDCARD_DOMAIN KASM_DOMAIN SIMPLEMEM_URL CLOUDFLARE_TUNNEL_NAME"

MANIFEST_FILE="${SOURCE_ENV}.manifest"
{
    echo "# ======================================================================"
    echo "# Admin Profile Configuration"
    echo "# Secret values stored in vault.age"
    echo "# Non-secret values editable directly here"
    echo "# ======================================================================"
    echo ""

    local_section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Pass through comments and blank lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            echo "$line"
            continue
        fi

        # Skip lines without =
        [[ "$line" != *"="* ]] && continue

        key="${line%%=*}"
        value="${line#*=}"

        # Check if this is a non-secret key
        is_nonsecret=false
        for ns_key in $NON_SECRET_KEYS; do
            if [[ "$key" == "$ns_key" ]]; then
                is_nonsecret=true
                break
            fi
        done

        if [[ "$is_nonsecret" == "true" ]]; then
            # Keep non-secret values populated
            echo "${key}=${value}"
        else
            # Secret: show key, empty value, comment
            printf '%-45s # in vault\n' "${key}="
        fi
    done < <(age -d -i "$AGE_KEY" "$VAULT_FILE" 2>/dev/null)
} > "$MANIFEST_FILE"

# Replace original .env with manifest
mv "$MANIFEST_FILE" "$SOURCE_ENV"
log_ok "Manifest .env written: $SOURCE_ENV"
log_info "All keys visible. Secret values stored only in vault.age"

# --- Done ---
echo ""
echo -e "${GREEN}=== Migration Complete ===${NC}"
echo "Vault:     $VAULT_FILE ($SECRET_COUNT secrets)"
echo "Manifest:  $SOURCE_ENV (keys visible, secrets empty)"
echo "Key:       $AGE_KEY"
echo ""
echo "Test with:"
echo "  secrets --list             # List all keys"
echo "  secrets HCLOUD_TOKEN       # Get single secret"
echo "  eval \$(secrets -s)         # Load all to shell"
echo ""
echo "Load in scripts:"
echo "  source load-profile.sh     # Auto-decrypts when ADMIN_VAULT=enabled"
