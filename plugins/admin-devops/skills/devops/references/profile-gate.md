# Profile Gate (Supplementary Reference)

> **Note**: The critical profile gate instructions are in `SKILL.md`. This file provides
> supplementary details and load commands.

> **Path resolution**: These scripts live in the admin skill's `scripts/` directory.
> Resolve via sibling skill: `${SKILL_DIR}/../admin/scripts/` where `SKILL_DIR` is
> derived from the loaded SKILL.md path at runtime.

---

## Quick Test Commands

**Bash (WSL/Linux/macOS):**
```bash
"${SKILL_DIR}/../admin/scripts/test-admin-profile.sh"
```

Returns JSON: `{"exists":true|false,"path":"...","device":"...",...}`

---

## Create Profile (TUI-First Approach)

If profile doesn't exist, hand off to the **admin** skill which owns profile creation.
The admin skill's TUI interview will:
1. Ask storage location (single/multi-device)
2. Ask tool preferences (optional)
3. Ask about inventory scan (optional)
4. Call the setup script with answers:

```bash
"${SKILL_DIR}/../admin/scripts/new-admin-profile.sh" \
  --admin-root "$HOME/.admin" \
  --pkg-mgr "apt" \
  --py-mgr "uv" \
  --node-mgr "npm" \
  --shell-default "bash" \
  --run-inventory
```

Add `--multi-device` for cloud-synced storage.

---

## Load Profile

```bash
source "${SKILL_DIR}/../admin/scripts/load-profile.sh"
load_admin_profile
```

---

## WSL Note (Critical)

When running in WSL, the profile data lives on the Windows filesystem. A **satellite `.env`** at
`~/.admin/.env` points scripts to the correct location automatically:

```env
# ~/.admin/.env (created during setup)
ADMIN_ROOT=/mnt/c/Users/Owner/.admin
ADMIN_DEVICE=WOPR3
ADMIN_PLATFORM=wsl
```

All helper scripts read the satellite `.env` first - no `cmd.exe` calls needed.
