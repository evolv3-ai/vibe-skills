# Fresh Ubuntu Setup Transcript (with admin skill)

**Scenario:** Setting up admin on a fresh Ubuntu machine with user preferences: uv for Python, pnpm for Node.

**Platform detected:** Linux (standalone Ubuntu)

---

## Step 1: Profile Gate (Mandatory First Step)

Run the profile test script to check if a profile already exists:

```bash
/path/to/skills/admin/scripts/test-admin-profile.sh
```

**Expected output (fresh machine):**

```json
{"exists":false,"path":"","device":"","platform":"linux"}
```

Profile does not exist. Must run TUI setup interview before proceeding.

---

## Step 2: TUI Setup Interview

### Q1: Storage Location

**Agent asks:** "Will you use Admin on a single device or multiple devices?"

| Option | Description |
|--------|-------------|
| Single device (Recommended) | Local storage at `~/.admin`. Simple, no sync needed. |
| Multiple devices | Cloud-synced folder (Dropbox, OneDrive, NAS). Profiles shared across machines. |

**User answers:** Single device

**Result:** `ADMIN_ROOT` will be set to `~/.admin`.

---

### Q2: Tool Preferences

**Agent asks:** "Set tool preferences now, or use defaults?"

**User answers:** Yes, set preferences now.

**Agent asks:** "Package manager (Linux):" apt (default) / brew / dnf / pacman

**User answers:** apt (default)

**Agent asks:** "Python manager:" uv (default) / pip / conda / poetry

**User answers:** uv

**Agent asks:** "Node manager:" npm (default) / pnpm / yarn / bun

**User answers:** pnpm

**Agent asks:** "Default shell:" bash (default on Linux) / zsh / fish

**User answers:** bash (default)

---

### Q3: Inventory Scan

**Agent asks:** "Run a quick inventory scan to detect installed tools?"

**User answers:** Yes

---

## Step 3: Create Profile

Based on the user's answers, the agent would run:

```bash
scripts/new-admin-profile.sh \
  --admin-root "$HOME/.admin" \
  --pkg-mgr "apt" \
  --py-mgr "uv" \
  --node-mgr "pnpm" \
  --shell-default "bash" \
  --run-inventory
```

**Expected behavior:**
1. Creates `~/.admin/` directory structure:
   - `~/.admin/.env` (satellite config)
   - `~/.admin/profiles/<HOSTNAME>.json` (device profile)
   - `~/.admin/logs/` (log directory)
   - `~/.admin/issues/` (issue tracking)
2. Populates satellite `.env` with:
   ```env
   # Admin satellite config - points to centralized profile
   # Do not store secrets here. See $ADMIN_ROOT/.env for credentials.
   ADMIN_ROOT=/home/<user>/.admin
   ADMIN_DEVICE=<HOSTNAME>
   ADMIN_PLATFORM=linux
   ```
3. Creates profile JSON with preferences:
   ```json
   {
     "device": "<HOSTNAME>",
     "platform": "linux",
     "preferences": {
       "packages": { "manager": "apt" },
       "python": { "manager": "uv" },
       "node": { "manager": "pnpm" },
       "shell": { "default": "bash" }
     },
     "tools": { ... },
     "capabilities": { ... }
   }
   ```
4. Runs inventory scan to detect installed tools (git, node, python, docker, ssh, etc.) and records their versions into `profile.tools`.

---

## Step 4: Verify Profile Creation

Re-run the profile test to confirm:

```bash
scripts/test-admin-profile.sh
```

**Expected output:**

```json
{"exists":true,"path":"/home/<user>/.admin/profiles/<HOSTNAME>.json","device":"<HOSTNAME>","platform":"linux"}
```

---

## Step 5: Load Profile

Load the profile into the current session:

```bash
source scripts/load-profile.sh
load_admin_profile
```

**Expected behavior:** Exports `ADMIN_ROOT`, `ADMIN_DEVICE`, `ADMIN_PLATFORM`, and profile preferences into the current shell environment.

---

## Step 6: Log the Operation

```bash
source scripts/log-admin-event.sh
log_admin_event "Profile created for fresh Ubuntu setup (apt, uv, pnpm, bash)" "OK"
```

**Log destinations:**
- `~/.admin/logs/central/operations.log`
- `~/.admin/devices/<HOSTNAME>/logs.txt`

---

## Step 7: Confirm Ready

The profile gate is satisfied. The agent would now confirm to the user:

> Profile created successfully. Your preferences are set:
> - Package manager: **apt**
> - Python manager: **uv**
> - Node manager: **pnpm**
> - Default shell: **bash**
> - Inventory scan: completed
>
> You can now use any admin skill commands. Tool installations will use your preferred managers (e.g., `uv pip install` for Python packages, `pnpm install` for Node packages).

---

## Summary of Commands (in order)

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `scripts/test-admin-profile.sh` | Check if profile exists (returns `false`) |
| 2 | TUI interview (3 questions) | Gather user preferences |
| 3 | `scripts/new-admin-profile.sh --admin-root "$HOME/.admin" --pkg-mgr "apt" --py-mgr "uv" --node-mgr "pnpm" --shell-default "bash" --run-inventory` | Create profile with preferences |
| 4 | `scripts/test-admin-profile.sh` | Verify profile exists (returns `true`) |
| 5 | `source scripts/load-profile.sh && load_admin_profile` | Load profile into session |
| 6 | `source scripts/log-admin-event.sh && log_admin_event "Profile created for fresh Ubuntu setup (apt, uv, pnpm, bash)" "OK"` | Log the operation |
