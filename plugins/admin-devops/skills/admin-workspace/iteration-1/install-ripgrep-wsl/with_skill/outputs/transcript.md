# Transcript: Install ripgrep on WSL

## Task

Install ripgrep (`rg`) on this WSL2 Ubuntu 24.04 machine using the admin skill workflow.

---

## Step 1: Profile Gate (Mandatory First Step)

Per the skill's mandatory profile gate, run the profile check before any operation.

```bash
/home/wsladmin/dev/vibe-skills/plugins/admin-devops/skills/admin/scripts/test-admin-profile.sh
```

**Expected output:** JSON like `{"exists":true,"device":"WOPR3","adminRoot":"/mnt/c/Users/Owner/.admin","platform":"linux"}`

**If `exists: false`:** Stop. Run `/setup-profile` (the TUI setup interview) before proceeding. Do not continue with installation.

**If `exists: true`:** Proceed to Step 2.

---

## Step 2: Load Profile and Check Preferences

Source the profile loader to get `PROFILE_PATH` and device preferences.

```bash
source /home/wsladmin/dev/vibe-skills/plugins/admin-devops/skills/admin/scripts/load-profile.sh
load_admin_profile
```

Check the preferred package manager (should be `apt` per CLAUDE.md preferences):

```bash
jq -r '.preferences.packages.manager' "$PROFILE_PATH"
```

**Expected output:** `apt`

---

## Step 3: Check if ripgrep Is Already Installed

Before installing, check whether ripgrep is already present on the system.

```bash
which rg && rg --version
```

**If ripgrep is already installed:** Log the finding and stop. No installation needed.

**If not found:** Proceed to Step 4.

---

## Step 4: Query SimpleMem for Past Issues (Optional)

Check SimpleMem for any past issues with ripgrep installation, if available.

```
memory_query("ripgrep install WSL")
```

**If SimpleMem is unavailable:** Continue without it (graceful degradation).

**If past issues found:** Review and adapt the installation plan accordingly.

---

## Step 5: Install ripgrep via apt

Since the profile preference is `apt`, use the system package manager.

```bash
sudo apt update
```

```bash
sudo apt install -y ripgrep
```

---

## Step 6: Verify Installation

Confirm ripgrep installed correctly and get the version.

```bash
rg --version
```

**Expected output:** Something like `ripgrep 14.x.x` (version depends on the Ubuntu 24.04 apt repository).

Quick functional test:

```bash
echo "hello world" | rg "hello"
```

**Expected output:** `hello world` (with "hello" highlighted).

---

## Step 7: Update Profile with New Tool

Record the installed tool in the device profile's WSL tools section.

```bash
PROFILE=$(cat "$PROFILE_PATH")
PROFILE=$(echo "$PROFILE" | jq --arg ver "$(rg --version | head -1)" \
    '.wsl.distributions["Ubuntu-24.04"].tools.ripgrep.version = $ver')
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Step 8: Log the Operation (Mandatory)

Log the installation using the admin skill's logging helper.

```bash
source /home/wsladmin/dev/vibe-skills/plugins/admin-devops/skills/admin/scripts/log-admin-event.sh
log_admin_event "Installed ripgrep via apt on WSL" "OK"
```

This writes to:
- `/mnt/c/Users/Owner/.admin/logs/central/operations.log`
- `/mnt/c/Users/Owner/.admin/devices/WOPR3/logs.txt`

---

## Step 9: Store in SimpleMem (Optional)

If SimpleMem is available, record the installation for future reference.

```
memory_add(
  speaker: "admin:tool-installer",
  text: "Installed ripgrep via apt on WSL Ubuntu 24.04 (WOPR3). Package: ripgrep. Version: <version from step 6>. No issues encountered."
)
```

**If SimpleMem is unavailable:** Skip. Never fail the operation because of SimpleMem.

---

## Summary

| Step | Action | Command/Tool |
|------|--------|-------------|
| 1 | Profile gate check | `test-admin-profile.sh` |
| 2 | Load profile, check package manager preference | `load-profile.sh`, `jq` |
| 3 | Check if already installed | `which rg && rg --version` |
| 4 | Query SimpleMem for past issues | `memory_query` (optional) |
| 5 | Install via apt | `sudo apt install -y ripgrep` |
| 6 | Verify installation | `rg --version` |
| 7 | Update device profile | `jq` write to `$PROFILE_PATH` |
| 8 | Log the operation | `log-admin-event.sh` |
| 9 | Store in SimpleMem | `memory_add` (optional) |
