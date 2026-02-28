# Admin Vault Guide

Lightweight, git-safe secrets management using [age encryption](https://age-encryption.org/) integrated with the admin suite's satellite `.env` / profile architecture.

## Quick Start

### 1. Install age

```bash
# Linux/WSL
sudo apt install age

# macOS
brew install age

# Windows
scoop install age
# or: choco install age
```

### 2. Generate key

Choose a location accessible to all shells on this machine:

```bash
# WSL + Windows (shared via NTFS - both sides can reach it)
mkdir -p /mnt/c/Users/$USER/.age
age-keygen -o /mnt/c/Users/$USER/.age/key.txt

# macOS / Linux (single platform)
mkdir -p ~/.age
age-keygen -o ~/.age/key.txt
chmod 600 ~/.age/key.txt
```

Save the public key shown (starts with `age1...`). Back up the key somewhere safe.

### 3. Migrate existing .env

```bash
# Run migration script
./skills/admin/scripts/migrate-to-vault.sh

# Or manually:
PUBLIC_KEY=$(age-keygen -y ~/.age/key.txt)
age -e -r "$PUBLIC_KEY" -a -o $ADMIN_ROOT/vault.age $ADMIN_ROOT/.env
```

### 4. Enable vault

Add to `~/.admin/.env`:
```bash
ADMIN_VAULT=enabled
AGE_KEY_PATH=/mnt/c/Users/Owner/.age/key.txt   # Explicit path (cross-platform)
```

`AGE_KEY_PATH` tells all scripts (bash, PowerShell, TypeScript) where to find the key. If omitted, defaults to `~/.age/key.txt`. Set it explicitly on WSL or multi-device setups where `$HOME` differs between shells.

### 5. Test

**Bash:**
```bash
secrets --status           # Check everything is wired up
secrets --list             # See all keys
secrets HCLOUD_TOKEN       # Get a single value
eval $(secrets -s)         # Load all to shell
```

**PowerShell:**
```powershell
.\secrets.ps1 -Status     # Check everything is wired up
.\secrets.ps1 -List        # See all keys
.\secrets.ps1 HCLOUD_TOKEN # Get a single value
.\secrets.ps1 -Source | Invoke-Expression  # Load all to env
```

> **Note**: Bash uses `--double-dash` flags. PowerShell uses `-PascalCase` switches. Do not mix them.

## Daily Usage

### Retrieve secrets

**Bash:**
```bash
# Single value
secrets HCLOUD_TOKEN
HCLOUD_TOKEN=$(secrets HCLOUD_TOKEN)

# All values as env vars
eval $(secrets -s)

# List keys
secrets --list

# View all (for debugging)
secrets --decrypt
```

**PowerShell:**
```powershell
# Single value
.\secrets.ps1 HCLOUD_TOKEN
$token = .\secrets.ps1 HCLOUD_TOKEN

# All values as env vars
.\secrets.ps1 -Source | Invoke-Expression

# List keys
.\secrets.ps1 -List

# View all (for debugging)
.\secrets.ps1 -Decrypt
```

### Edit vault

```bash
# Opens vault in $EDITOR, re-encrypts on save (Bash only)
secrets --edit
```

### Add new secret

```bash
secrets --edit
# Add: NEW_API_KEY=abc123
# Save and close editor
```

### Encrypt from scratch

```bash
# Write secrets to a temp file
cat > /tmp/new-secrets.env << 'EOF'
HCLOUD_TOKEN=your-token
OCI_TENANCY_OCID=your-ocid
EOF

# Encrypt to vault
secrets --encrypt /tmp/new-secrets.env

# Delete plaintext
rm /tmp/new-secrets.env
```

## Integration with admin scripts

### Bash (load-profile.sh)

```bash
source load-profile.sh

# If ADMIN_VAULT=enabled in ~/.admin/.env:
#   → Decrypts vault, exports vars to environment
# If ADMIN_VAULT=disabled or not set:
#   → Loads plaintext $ADMIN_ROOT/.env (existing behavior)

# Explicit call:
load_admin_secrets
```

### PowerShell (Load-Profile.ps1)

```powershell
. .\Load-Profile.ps1
Load-AdminProfile -Export    # Includes vault decryption

# Explicit call:
$secrets = Load-AdminSecrets -ExportToEnvironment
$secrets['HCLOUD_TOKEN']

# Or use secrets.ps1 directly:
$token = .\secrets.ps1 HCLOUD_TOKEN
.\secrets.ps1 -Source | Invoke-Expression   # Load all to $env:
```

### TypeScript (admin-vault.ts)

```typescript
import { decryptVault, getSecret, listSecrets, exportSecrets } from './admin-vault'

// Get all secrets
const secrets = await decryptVault()   // Map<string, string>
const token = secrets.get('HCLOUD_TOKEN')

// Convenience functions
const token = await getSecret('HCLOUD_TOKEN')
const keys = await listSecrets()        // string[]
const count = await exportSecrets()     // exports to process.env, returns count
```

Requires: `npm install age-encryption`

## Architecture

```
~/.admin/.env (satellite - per-device bootstrap, no secrets)
  ADMIN_ROOT=/mnt/c/Users/Owner/.admin
  ADMIN_DEVICE=WOPR3
  ADMIN_PLATFORM=wsl
  ADMIN_VAULT=enabled                                ← Feature flag
  AGE_KEY_PATH=/mnt/c/Users/Owner/.age/key.txt       ← Explicit key location

$AGE_KEY_PATH (private key - NEVER commit/sync)
  AGE-SECRET-KEY-1...

$ADMIN_ROOT/vault.age (encrypted - git-safe, sync-safe)
  -----BEGIN AGE ENCRYPTED FILE-----
  [base64 encrypted content]
  -----END AGE ENCRYPTED FILE-----

$ADMIN_ROOT/.env (manifest - all keys visible, secrets empty)
  ADMIN_ROOT=/mnt/c/Users/Owner/.admin               ← non-secret: populated
  HCLOUD_TOKEN=                                       # in vault  ← secret: empty
  OCI_TENANCY_OCID=                                   # in vault
  ...
```

### .env Manifest Pattern

After vault migration, the `.env` file becomes a **manifest** rather than being deleted:

- **Non-secret values** (ADMIN_ROOT, ADMIN_DEVICE, SIMPLEMEM_URL, etc.) stay populated and editable
- **Secret values** (tokens, passwords, API keys) show empty with `# in vault` comment
- Users can see all config keys at a glance without decrypting the vault
- New non-secret keys can be added directly to the manifest
- New secrets should be added via `secrets --edit` (updates vault) and then added to the manifest with an empty value for documentation

**How load-profile handles it:**
- When `ADMIN_VAULT=enabled`: vault.age is decrypted, full secret values loaded
- When vault disabled/missing: manifest `.env` is loaded (empty secret values = no secrets available)
- The vault always takes precedence; the manifest serves as documentation, not a secret source

**Generated by:** `migrate-to-vault.sh` / `migrate-to-vault.ps1` (automatically replaces plaintext .env with manifest after encryption)

### Key Path Resolution

All scripts (bash, PowerShell, TypeScript) resolve the age key in order:

1. `$AGE_KEY_PATH` environment variable (if set)
2. `AGE_KEY_PATH=` in `~/.admin/.env` (satellite config)
3. `$HOME/.age/key.txt` (default fallback)

This allows each device to store the key wherever makes sense for its platform while the vault file stays in the shared `$ADMIN_ROOT`.

### WSL + Windows (Same Machine)

On WSL/Windows dual setups, `$HOME` differs between shells:

| Shell | `$HOME` | Default key path |
|-------|---------|-----------------|
| Bash (WSL) | `/home/user` | `/home/user/.age/key.txt` |
| PowerShell (Win) | `C:\Users\Owner` | `C:\Users\Owner\.age\key.txt` |

Store the key on the Windows filesystem so both sides can reach it:

```
Physical:   C:\Users\Owner\.age\key.txt
WSL sees:   /mnt/c/Users/Owner/.age/key.txt
PowerShell: C:\Users\Owner\.age\key.txt  (via auto WSL path conversion)
```

Set `AGE_KEY_PATH` in the satellite `.env` to the WSL-style path. PowerShell scripts automatically convert `/mnt/c/...` to `C:\...`.

## Feature Flag

The `ADMIN_VAULT` variable in `~/.admin/.env` controls behavior:

| Value | Behavior |
|-------|----------|
| `enabled` | Decrypt vault.age, export secrets to env |
| `disabled` | Load plaintext .env (original behavior) |
| not set | Same as disabled |

**Graceful degradation**: If vault is enabled but dependencies are missing (age CLI, key file, vault file), scripts warn and fall back to plaintext `.env`.

## Key Backup

The age private key at `~/.age/key.txt` is the single point of failure. If lost, the vault cannot be decrypted.

**Backup strategies**:
- Print the key (it's one line, ~74 characters)
- Store in a password manager (1Password, Bitwarden)
- Copy to a USB drive stored securely
- Store encrypted copy in a different system

**Do NOT**:
- Commit `~/.age/key.txt` to git
- Sync via Dropbox/OneDrive (unless encrypted)
- Store alongside vault.age (defeats encryption)

## Multi-Device with Sync

The vault integrates naturally with the admin suite's multi-device sync feature (`ADMIN_SYNC_PATH`). The vault file is age-encrypted, making it **safe to sync** via Dropbox, OneDrive, Google Drive, or any cloud storage.

### Setup

```
SYNCED ($ADMIN_ROOT on shared storage)       LOCAL (per-device, never synced)
══════════════════════════════════════       ═══════════════════════════════
/mnt/n/Dropbox/Admin/                        ~/.admin/.env  (satellite)
  ├── profiles/WOPR3.json                    ~/.age/key.txt (or AGE_KEY_PATH)
  ├── profiles/MACBOOK.json
  ├── logs/
  ├── issues/
  └── vault.age  ← encrypted, safe ✅
```

### Steps

1. **Set `ADMIN_ROOT` to the shared path** on each device's satellite `.env`:
   ```bash
   # Device A (WSL)
   ADMIN_ROOT=/mnt/n/Dropbox/Admin
   AGE_KEY_PATH=/mnt/c/Users/Owner/.age/key.txt

   # Device B (macOS)
   ADMIN_ROOT=/Users/jez/Dropbox/Admin
   AGE_KEY_PATH=/Users/jez/.age/key.txt

   # Device C (Linux)
   ADMIN_ROOT=/home/jez/Dropbox/Admin
   AGE_KEY_PATH=/home/jez/.age/key.txt
   ```

2. **Copy the age key** to each device via a secure channel (USB, SSH, password manager). The key is one line (~74 chars) - easy to transfer.

3. **Set `ADMIN_VAULT=enabled`** in each device's satellite `.env`.

All devices decrypt the same `vault.age` from the synced `$ADMIN_ROOT`. When one device runs `secrets --edit`, the updated vault syncs to all devices automatically.

### What syncs vs. what stays local

| Item | Synced? | Why |
|------|---------|-----|
| `vault.age` | Yes | Encrypted, opaque to cloud storage |
| `profiles/*.json` | Yes | Device configs, no secrets |
| `logs/`, `issues/` | Yes | "Wisdom of crowds" benefit |
| `key.txt` | **No** | The one secret that unlocks everything |
| `~/.admin/.env` | **No** | Per-device satellite bootstrap |

## Troubleshooting

### "Age key not found"
```bash
age-keygen -o ~/.age/key.txt
chmod 600 ~/.age/key.txt
```

### "Vault not found"
```bash
secrets --encrypt $ADMIN_ROOT/.env
# Or run: migrate-to-vault.sh
```

### "Decryption failed"
- Wrong key: `age-keygen -y ~/.age/key.txt` shows the public key. It must match the one used to encrypt.
- Corrupted vault: Re-encrypt from plaintext backup.

### "age not installed"
```bash
sudo apt install age    # Linux/WSL
brew install age        # macOS
scoop install age       # Windows
```

### Vault enabled but still loading plaintext
Check `~/.admin/.env` has `ADMIN_VAULT=enabled` (not `ADMIN_VAULT=true` or other values).

### PowerShell: "age is not recognized"
Add age to PATH or install via scoop/choco which auto-configures PATH.
