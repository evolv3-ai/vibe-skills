#!/usr/bin/env bash
# =============================================================================
# Sync Profile - GitHub remote profile sync
# =============================================================================
# Syncs the admin profile directory ($ADMIN_ROOT/profiles/) with a private
# GitHub repo. Pulls if stale (>1hr since last pull), auto-commits and pushes
# if local changes detected.
#
# Skips silently if ADMIN_PROFILE_REPO is not configured.
#
# Usage:
#   sync-profile.sh              # Auto sync (pull if stale, push if changed)
#   sync-profile.sh --pull       # Force pull
#   sync-profile.sh --push       # Force commit + push
#   sync-profile.sh --status     # Show sync status
#   sync-profile.sh --init       # Initialize repo from existing profiles dir
#
# Configuration (in ~/.admin/.env):
#   ADMIN_PROFILE_REPO=git@github.com:user/admin-profiles.git
#   ADMIN_PROFILE_AUTO_PULL=true|false (default: false)
# =============================================================================

set -euo pipefail

SATELLITE_ENV="${HOME}/.admin/.env"

# --- Resolve config ---
read_satellite_var() {
    local var_name="$1"
    grep "^${var_name}=" "$SATELLITE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2- || true
}

resolve_admin_root() {
    if [[ -n "${ADMIN_ROOT:-}" ]]; then echo "$ADMIN_ROOT"; return; fi
    if [[ -f "$SATELLITE_ENV" ]]; then
        local root
        root=$(read_satellite_var "ADMIN_ROOT")
        if [[ -n "$root" ]]; then echo "$root"; return; fi
    fi
    echo "${HOME}/.admin"
}

ADMIN_ROOT="$(resolve_admin_root)"
PROFILES_DIR="${ADMIN_ROOT}/profiles"
PROFILE_REPO=""
AUTO_PULL="false"
STALE_THRESHOLD=3600  # 1 hour in seconds

if [[ -f "$SATELLITE_ENV" ]]; then
    PROFILE_REPO=$(read_satellite_var "ADMIN_PROFILE_REPO")
    AUTO_PULL=$(read_satellite_var "ADMIN_PROFILE_AUTO_PULL")
fi
AUTO_PULL="${AUTO_PULL:-false}"

# --- Helpers ---
log_info() { echo "[INFO] $1"; }
log_ok()   { echo "[OK]   $1"; }
log_warn() { echo "[WARN] $1"; }
log_err()  { echo "[ERR]  $1" >&2; }

is_git_repo() {
    git -C "$PROFILES_DIR" rev-parse --is-inside-work-tree &>/dev/null
}

last_pull_age() {
    local fetch_head="${PROFILES_DIR}/.git/FETCH_HEAD"
    if [[ -f "$fetch_head" ]]; then
        local last_mod
        last_mod=$(stat -c '%Y' "$fetch_head" 2>/dev/null || stat -f '%m' "$fetch_head" 2>/dev/null)
        local now
        now=$(date +%s)
        echo $(( now - last_mod ))
    else
        echo "999999"  # Never fetched
    fi
}

has_local_changes() {
    local status
    status=$(git -C "$PROFILES_DIR" status --porcelain 2>/dev/null)
    [[ -n "$status" ]]
}

# --- Operations ---
do_init() {
    if [[ -z "$PROFILE_REPO" ]]; then
        log_err "ADMIN_PROFILE_REPO not set in $SATELLITE_ENV"
        exit 1
    fi

    if is_git_repo; then
        log_warn "Already a git repo: $PROFILES_DIR"
        log_info "Remote: $(git -C "$PROFILES_DIR" remote get-url origin 2>/dev/null || echo 'none')"
        exit 0
    fi

    if [[ ! -d "$PROFILES_DIR" ]]; then
        log_err "Profiles directory not found: $PROFILES_DIR"
        exit 1
    fi

    log_info "Initializing git repo in $PROFILES_DIR"
    git -C "$PROFILES_DIR" init -b main
    git -C "$PROFILES_DIR" remote add origin "$PROFILE_REPO"

    # Initial commit with existing profiles
    git -C "$PROFILES_DIR" add -A
    local file_count
    file_count=$(git -C "$PROFILES_DIR" diff --cached --name-only | wc -l)
    if [[ "$file_count" -gt 0 ]]; then
        git -C "$PROFILES_DIR" commit -m "feat: initial profile sync ($file_count files)"
        git -C "$PROFILES_DIR" push -u origin main
        log_ok "Initialized and pushed $file_count files"
    else
        log_warn "No files to commit"
    fi
}

do_pull() {
    if ! is_git_repo; then
        log_err "Not a git repo: $PROFILES_DIR (run: sync-profile.sh --init)"
        exit 1
    fi

    log_info "Pulling from $(git -C "$PROFILES_DIR" remote get-url origin 2>/dev/null)"
    git -C "$PROFILES_DIR" pull --rebase --autostash 2>&1
    log_ok "Pull complete"
}

do_push() {
    if ! is_git_repo; then
        log_err "Not a git repo: $PROFILES_DIR (run: sync-profile.sh --init)"
        exit 1
    fi

    if ! has_local_changes; then
        log_info "No local changes to push"
        return 0
    fi

    local device_name
    device_name=$(read_satellite_var "ADMIN_DEVICE")
    device_name="${device_name:-$(hostname)}"

    git -C "$PROFILES_DIR" add -A
    local changed_files
    changed_files=$(git -C "$PROFILES_DIR" diff --cached --name-only | head -5 | tr '\n' ', ')
    git -C "$PROFILES_DIR" commit -m "sync($device_name): profile update (${changed_files%,})"
    git -C "$PROFILES_DIR" push
    log_ok "Pushed profile changes"
}

do_status() {
    echo "Profile Sync Status"
    echo "────────────────────────────────────"
    echo "Profiles dir:  $PROFILES_DIR"
    echo "Repo:          ${PROFILE_REPO:-not configured}"
    echo "Auto-pull:     $AUTO_PULL"

    if [[ -z "$PROFILE_REPO" ]]; then
        echo "Status:        DISABLED (no ADMIN_PROFILE_REPO set)"
        return
    fi

    if ! is_git_repo; then
        echo "Status:        NOT INITIALIZED (run: sync-profile.sh --init)"
        return
    fi

    local age
    age=$(last_pull_age)
    local age_human
    if [[ "$age" -gt 86400 ]]; then
        age_human="$(( age / 86400 ))d ago"
    elif [[ "$age" -gt 3600 ]]; then
        age_human="$(( age / 3600 ))h ago"
    elif [[ "$age" -gt 60 ]]; then
        age_human="$(( age / 60 ))m ago"
    else
        age_human="${age}s ago"
    fi

    echo "Last fetch:    $age_human"
    echo "Stale:         $(( age > STALE_THRESHOLD ? 1 : 0 )) (threshold: ${STALE_THRESHOLD}s)"

    if has_local_changes; then
        echo "Local changes: YES"
        git -C "$PROFILES_DIR" status --short | head -10 | sed 's/^/  /'
    else
        echo "Local changes: none"
    fi

    local branch
    branch=$(git -C "$PROFILES_DIR" branch --show-current 2>/dev/null)
    echo "Branch:        ${branch:-detached}"
    echo "Remote:        $(git -C "$PROFILES_DIR" remote get-url origin 2>/dev/null || echo 'none')"
}

do_auto_sync() {
    # Skip silently if not configured
    if [[ -z "$PROFILE_REPO" ]]; then
        return 0
    fi

    if ! is_git_repo; then
        return 0
    fi

    # Pull if stale
    local age
    age=$(last_pull_age)
    if [[ "$age" -gt "$STALE_THRESHOLD" ]]; then
        log_info "Profile repo stale (${age}s) - pulling"
        git -C "$PROFILES_DIR" pull --rebase --autostash 2>&1 || log_warn "Pull failed (offline?)"
    fi

    # Push if local changes
    if has_local_changes; then
        do_push
    fi
}

# --- Main ---
case "${1:-}" in
    --init)
        do_init
        ;;
    --pull)
        do_pull
        ;;
    --push)
        do_push
        ;;
    --status)
        do_status
        ;;
    -h|--help)
        echo "Usage: sync-profile.sh [--init|--pull|--push|--status|--help]"
        echo ""
        echo "  (no args)   Auto sync: pull if stale, push if changed"
        echo "  --init      Initialize profiles dir as git repo"
        echo "  --pull      Force pull from remote"
        echo "  --push      Commit + push local changes"
        echo "  --status    Show sync status"
        echo ""
        echo "Config (in ~/.admin/.env):"
        echo "  ADMIN_PROFILE_REPO=git@github.com:user/admin-profiles.git"
        echo "  ADMIN_PROFILE_AUTO_PULL=true|false"
        ;;
    "")
        do_auto_sync
        ;;
    *)
        log_err "Unknown option: $1"
        echo "Run: sync-profile.sh --help" >&2
        exit 1
        ;;
esac
