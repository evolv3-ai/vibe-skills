# Remote Profile Sync

Sync the admin profiles directory with a private GitHub repo for multi-device access and version history.

## Contents

- [Overview](#overview)
- [GitHub Repo Setup](#github-repo-setup)
- [Initial Push](#initial-push)
- [Sync Scripts](#sync-scripts)
- [Profile Gate Integration](#profile-gate-integration)
- [New Device Onboarding](#new-device-onboarding)
- [What Syncs vs Stays Local](#what-syncs-vs-stays-local)
- [Troubleshooting](#troubleshooting)

## Overview

The profiles directory (`$ADMIN_ROOT/profiles/`) contains device profiles, server inventory, and deployment configs. Remote sync via a private GitHub repo provides:

- **Version history**: Every profile change is a git commit with device attribution
- **Multi-device access**: New devices clone the repo to get all profiles instantly
- **Backup**: Profile data is always recoverable from GitHub
- **Audit trail**: `git log` shows what changed, when, and from which device

This is independent of Dropbox/OneDrive sync (`ADMIN_SYNC_PATH`) — GitHub sync is git-native and works offline with periodic push.

## GitHub Repo Setup

Create a private repo to store profiles:

```bash
# Create private repo (requires gh CLI)
gh repo create admin-profiles --private --description "Admin device profiles"

# Or manually at github.com → New Repository → Private
```

The repo URL goes in `~/.admin/.env`:
```bash
ADMIN_PROFILE_REPO=git@github.com:youruser/admin-profiles.git
ADMIN_PROFILE_AUTO_PULL=true
```

Use SSH URL (`git@github.com:...`) for key-based auth. HTTPS works but requires credential caching.

## Initial Push

Initialize the profiles directory as a git repo and push existing profiles:

**Bash (WSL/Linux/macOS):**
```bash
scripts/sync-profile.sh --init
```

**PowerShell (Windows):**
```powershell
.\scripts\Sync-DeviceProfile.ps1 -RepoInit
```

This does:
1. `git init -b main` in the profiles directory
2. `git remote add origin` with the configured repo URL
3. Commits all existing profile files
4. Pushes to `origin/main`

## Sync Scripts

### Bash: sync-profile.sh

```bash
scripts/sync-profile.sh              # Auto sync (pull if stale, push if changed)
scripts/sync-profile.sh --pull       # Force pull
scripts/sync-profile.sh --push       # Force commit + push
scripts/sync-profile.sh --status     # Show sync status
scripts/sync-profile.sh --init       # Initialize repo
```

**Auto sync behavior** (no args):
- Skips silently if `ADMIN_PROFILE_REPO` is not set
- Pulls if last fetch was more than 1 hour ago
- Commits and pushes if local changes exist
- Commit messages include device name: `sync(WOPR3): profile update (WOPR3.json)`

### PowerShell: Sync-DeviceProfile.ps1

```powershell
.\scripts\Sync-DeviceProfile.ps1 -RepoSync      # Pull + push
.\scripts\Sync-DeviceProfile.ps1 -RepoInit       # Initialize repo
.\scripts\Sync-DeviceProfile.ps1 -RepoStatus     # Show sync status
```

The PowerShell script also retains its existing tool verification features (`-UpdateVersions`, `-ResolveConflicts`).

## Profile Gate Integration

The profile gate (`test-admin-profile.sh` / `Test-AdminProfile.ps1`) now includes `profileRepo` in its JSON output when configured:

```json
{
  "exists": true,
  "device": "WOPR3",
  "adminRoot": "/mnt/c/Users/Owner/.admin",
  "secretsBackend": "infisical",
  "profileRepo": "git@github.com:user/admin-profiles.git"
}
```

This lets agents and scripts detect whether remote sync is available without reading the satellite `.env` directly.

## New Device Onboarding

When setting up a new device with remote profile sync:

1. **Create satellite `.env`** at `~/.admin/.env`:
   ```bash
   ADMIN_ROOT=/path/to/.admin
   ADMIN_DEVICE=NEW-DEVICE
   ADMIN_PLATFORM=linux
   ADMIN_PROFILE_REPO=git@github.com:user/admin-profiles.git
   ADMIN_PROFILE_AUTO_PULL=true
   ```

2. **Clone profiles** into the admin root:
   ```bash
   git clone git@github.com:user/admin-profiles.git $ADMIN_ROOT/profiles
   ```

3. **Create device profile** if it doesn't exist:
   ```bash
   scripts/new-admin-profile.sh
   ```

4. **Push new profile**:
   ```bash
   scripts/sync-profile.sh --push
   ```

The new device's profile is now visible to all other synced devices.

## What Syncs vs Stays Local

| Item | Synced via Repo | Why |
|------|----------------|-----|
| `profiles/*.json` | Yes | Device configs, server inventory |
| `profiles/.git/` | N/A | Git metadata (local to each clone) |
| `~/.admin/.env` | **No** | Per-device satellite bootstrap |
| `vault.age` | **No** | Encrypted secrets (separate sync) |
| `~/.age/key.txt` | **No** | Private key (never leaves device) |
| `logs/` | **No** | Device-specific operation logs |
| `issues/` | Optional | Can be tracked in git if shared |

The profiles repo contains **only** the `profiles/` directory contents, not the entire `$ADMIN_ROOT`. Secrets, keys, and logs stay out of the repo.

## Troubleshooting

### "Not a git repo"

Run `sync-profile.sh --init` to initialize the profiles directory.

### "ADMIN_PROFILE_REPO not set"

Add to `~/.admin/.env`:
```bash
ADMIN_PROFILE_REPO=git@github.com:user/admin-profiles.git
```

### Push rejected (non-fast-forward)

Another device pushed first. Pull, then push:
```bash
scripts/sync-profile.sh --pull
scripts/sync-profile.sh --push
```

The pull uses `--rebase --autostash` to handle this cleanly.

### SSH key not working

Ensure your SSH key is added to GitHub and the ssh-agent:
```bash
ssh -T git@github.com          # Test connection
ssh-add ~/.ssh/id_rsa           # Add key to agent
```

### Sync not running automatically

Auto sync only runs when `sync-profile.sh` is called with no arguments. To integrate with session startup, add to `load-profile.sh` or call from session hooks.

`ADMIN_PROFILE_AUTO_PULL` is read by the scripts but must be invoked — it doesn't run as a background daemon.
