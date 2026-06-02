# WSL Administration

_Consolidated from `skills/admin (wsl)` on 2026-02-02_

## Contents

- [Profile Gate](#profile-gate)
- [Quick Start](#quick-start)
- [Critical Rules](#critical-rules)
- [Check WSL Config from Profile](#check-wsl-config-from-profile)
- [Package Installation (Profile-Aware)](#package-installation-profile-aware)
- [Docker Operations](#docker-operations)
- [Path Conversions](#path-conversions)
- [SSH to Servers](#ssh-to-servers)
- [Update Profile from WSL](#update-profile-from-wsl)
- [Resource Limits](#resource-limits)
- [Capabilities Check](#capabilities-check)
- [Issues Tracking](#issues-tracking)
- [Common Tasks](#common-tasks)
- [Scope Boundaries](#scope-boundaries)
- [Troubleshooting](#troubleshooting)
- [Git Configuration](#git-configuration)
- [Known Issues Prevention](#known-issues-prevention)
- [Complete Setup Checklist](#complete-setup-checklist)
- [WSL Commands Reference](#wsl-commands-reference)
- [.wslconfig Reference](#wslconfig-reference)
- [Path Mapping & Resource Sizing](#path-mapping--resource-sizing)

**Requires**: WSL2 context, Ubuntu 24.04

---

## Profile Gate

Run the profile check before any operation. See `references/profile-gate.md` for full details.

```bash
scripts/test-admin-profile.sh
```

If `exists: false`, run the TUI setup interview (see profile-gate.md) before proceeding.

**WSL note**: The profile lives on the Windows side (`/mnt/c/Users/Owner/.admin`), not in WSL home. The satellite `.env` at `~/.admin/.env` points to the real location. See the "Shared Admin Root" section in profile-gate.md.

---

## Quick Start

The loader auto-detects WSL and uses the correct path:

```bash
source /path/to/admin/scripts/load-profile.sh
show_environment        # Verify detection (Type: WSL, Win User, ADMIN_ROOT, Profile, Exists)
load_admin_profile
show_admin_summary
```

---

## Critical Rules

**Always:**
- Keep profiles on the Windows side; access via `/mnt/c/Users/{WIN_USER}/.admin`
- Use Linux tools inside WSL (`apt`, `systemd`, `chmod`, `chown`)
- Convert Windows paths with `wslpath` before use in WSL scripts
- Run `apt` inside WSL (or `wsl -e apt ...` from Windows), not from PowerShell
- Treat Windows and WSL PATH as independent — set each explicitly
- Make `.wslconfig` changes on the Windows side, then `wsl --shutdown` to apply

**Never** (single-step, irreversible — recovery is out-of-band):
- Edit `.wslconfig` from inside WSL — the change silently no-ops (the file controls the VM from the Windows side)
- Edit Linux scripts with Windows tools that rewrite line endings (CRLF breaks the interpreter)

---

## Check WSL Config from Profile

```bash
jq '.wsl' "$PROFILE_PATH"                                   # WSL section
jq '.wsl.resourceLimits' "$PROFILE_PATH"                    # {"memory":"16GB","processors":8,"swap":"4GB"}
jq '.wsl.distributions["Ubuntu-24.04"].tools' "$PROFILE_PATH"
```

---

## Package Installation (Profile-Aware)

Read the preferred manager from the profile, then dispatch:

```bash
PY_MGR=$(jq -r '.preferences.python.manager' "$PROFILE_PATH")   # uv | pip | conda
case "$PY_MGR" in
    uv)    uv pip install "$package" ;;
    pip)   pip install "$package" ;;
    conda) conda install "$package" ;;
esac

NODE_MGR=$(jq -r '.preferences.node.manager' "$PROFILE_PATH")   # npm | pnpm | yarn | bun
case "$NODE_MGR" in
    npm)  npm install "$package" ;;
    pnpm) pnpm add "$package" ;;
    yarn) yarn add "$package" ;;
    bun)  bun add "$package" ;;
esac

# System packages
sudo apt update && sudo apt install -y "$package"
```

---

## Docker Operations

```bash
DOCKER_PRESENT=$(jq -r '.docker.present' "$PROFILE_PATH")
DOCKER_BACKEND=$(jq -r '.docker.backend' "$PROFILE_PATH")     # e.g. "WSL2" (Docker Desktop integration)

# Standard docker/compose verbs work as usual (ps, logs, exec -it <c> bash, compose up -d).
# Docker Desktop must be running on the Windows side for the socket to be present.
```

---

## Path Conversions

Profile paths are Windows-style and need conversion for WSL:

```bash
win_to_wsl() {   # "C:/Users/Owner/.ssh" -> "/mnt/c/Users/Owner/.ssh"
    local win_path="$1"
    local drive=$(echo "$win_path" | cut -c1 | tr '[:upper:]' '[:lower:]')
    local rest=$(echo "$win_path" | cut -c3- | sed 's|\\|/|g')
    echo "/mnt/$drive$rest"
}
WSL_SSH_PATH=$(win_to_wsl "$(jq -r '.paths.sshKeys' "$PROFILE_PATH")")
```

`wslpath -u 'C:\...'` and `wslpath -w /mnt/...` do the same conversions natively.

---

## SSH to Servers

```bash
SERVER=$(jq '.servers[] | select(.id == "cool-two")' "$PROFILE_PATH")
WSL_KEY=$(win_to_wsl "$(echo "$SERVER" | jq -r '.keyPath')")
ssh -i "$WSL_KEY" "$(echo "$SERVER" | jq -r '.username')@$(echo "$SERVER" | jq -r '.host')"

# Or use the loader helper (auto-converts paths):
source load-profile.sh && load_admin_profile && ssh_to_server "cool-two"
```

---

## Update Profile from WSL

```bash
PROFILE=$(cat "$PROFILE_PATH")
PROFILE=$(echo "$PROFILE" | jq --arg ver "$(node --version)" \
    '.wsl.distributions["Ubuntu-24.04"].tools.node.version = $ver')
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Resource Limits

Controlled by `.wslconfig` (Windows side); the profile tracks current settings:

```bash
jq '.wsl.resourceLimits' "$PROFILE_PATH"
```

To change them, the edit happens on the Windows side (see `references/windows.md`). Log the handoff:

```bash
echo "[$(date -Iseconds)] HANDOFF: Need .wslconfig change - increase memory to 24GB" \
    >> "$ADMIN_ROOT/logs/handoffs.log"
```

---

## Capabilities Check

```bash
HAS_DOCKER=$(jq -r '.capabilities.hasDocker' "$PROFILE_PATH")
HAS_GIT=$(jq -r '.capabilities.hasGit' "$PROFILE_PATH")
```

---

## Issues Tracking

```bash
jq '.issues.current[]' "$PROFILE_PATH"        # check known issues before troubleshooting

# Add a new issue:
PROFILE=$(cat "$PROFILE_PATH")
PROFILE=$(echo "$PROFILE" | jq '.issues.current += [{
    "id": "wsl-docker-'"$(date +%s)"'", "tool": "docker",
    "issue": "Docker socket not found", "priority": "high",
    "status": "pending", "created": "'"$(date -Iseconds)"'"}]')
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Common Tasks

```bash
sudo apt update && sudo apt upgrade -y          # update system

# Create a profile-aware Python venv:
PY_MGR=$(get_preferred_manager python)
if [[ "$PY_MGR" == "uv" ]]; then
    uv venv .venv && source .venv/bin/activate && uv pip install -r requirements.txt
else
    python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
fi
```

---

## Scope Boundaries

| Task | Handle Here | Otherwise |
|------|-------------|-----------|
| apt packages, Docker containers, Python/Node in WSL | ✅ | - |
| `.bashrc`/`.zshrc`, systemd services | ✅ | - |
| `.wslconfig`, Windows packages | ❌ | Windows side — `references/windows.md` |
| MCP servers | ❌ | `references/mcp.md` |
| Native Linux (non-WSL) | ❌ | `references/unix.md` |
| Remote servers / cloud | ❌ | **devops** skill |

---

## Troubleshooting

### WSL running slow / OOM

```bash
free -h; df -h; top
# If resource-constrained, the fix is a .wslconfig change on the Windows side:
log_admin_event "WSL slow - consider a .wslconfig memory increase (handoff to Windows side)" "WARN"
```

### Docker not working

```bash
docker info                       # Docker Desktop must be running (Windows side)
ls -la /var/run/docker.sock       # socket present?
```

### Package install fails

```bash
sudo apt update          # refresh first
df -h                    # check disk space
sudo apt clean && sudo apt autoclean
```

### uv not found

```bash
echo "$PATH" | grep ".local/bin" || {
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
}
```

### User D-Bus socket missing (`systemctl --user` services)

A user-service command (e.g. a gateway/agent restart) fails preflight with **"User D-Bus
socket is missing even though linger is enabled"**: `/run/user/<uid>/bus` doesn't exist even
though `systemctl --user` otherwise works. Default Ubuntu/WSL2 user sessions don't pull in
`dbus-user-session`, so no `dbus.socket` user unit ever starts the session bus.

```bash
sudo apt-get install -y dbus-user-session
systemctl --user daemon-reload && systemctl --user start dbus.socket
ls /run/user/$(id -u)/bus        # verify the socket now exists
```

Workaround if the package can't be installed: drive the unit directly, e.g.
`systemctl --user restart <service>.service`.

### Piper TTS / audio playback under WSLg

Local/offline TTS (e.g. Piper) plays through WSLg's PulseAudio bridge. Common gotchas:

- **Playback device**: WSLg's PulseServer is at `/mnt/wslg/PulseServer` (auto-set in `$PULSE_SERVER`).
- **`paplay` is usually absent on WSL**; `ffplay` (from the `ffmpeg` apt package) is the reliable
  fallback used to play the synthesized WAV. Install it if missing:
  ```bash
  sudo apt-get install -y ffmpeg
  ffplay -nodisp -autoexit -loglevel error /tmp/out.wav   # smoke test
  ```
- **`sounddevice` may import but raise `OSError: PortAudio library not found`** — not a blocker
  if an `ffplay`/`aplay` fallback exists. Install `libportaudio2` only if you need the
  `sounddevice` path.
- **Install `piper-tts` into the consuming app's own venv** (`uv pip install --python
  <venv>/bin/python piper-tts`), not as a `uv tool` — the app imports `from piper import
  PiperVoice` from its own Python. Voice models download via
  `python -m piper.download_voices <voice> --data-dir <dir>`.

---

## Git Configuration

```bash
git config --list          # view config
git config user.name; git config user.email
```

With Windows Git Credential Manager, the credential helper is configured automatically.

---

## Known Issues Prevention

| Issue | Cause | Prevention |
|-------|-------|------------|
| `.wslconfig` change ignored | Edited from inside WSL | Edit on Windows side, then `wsl --shutdown` |
| `apt: command not found` | Ran from PowerShell | Run inside WSL or `wsl -e apt install ...` |
| Path not found in script | Raw Windows path | Convert with `wslpath` |
| Scripts show `^M` / `bad interpreter` | CRLF line endings | `dos2unix` or `git config --global core.autocrlf input` |
| WSL VM keeps growing | Memory not reclaimed | `autoMemoryReclaim=gradual` in `.wslconfig` |
| Docker socket missing | Docker Desktop not running | Start Docker Desktop on Windows |
| Permission denied | Wrong ownership | `chown`/`chmod` |

---

## Complete Setup Checklist

- [ ] WSL2 with Ubuntu 24.04 installed
- [ ] Shell configured (zsh or bash)
- [ ] `uv` installed at `~/.local/bin/uv`
- [ ] Docker Desktop integration working
- [ ] Git configured with credentials
- [ ] `$ADMIN_ROOT` directory structure created; `.env` configured; central logs reachable

Docs: Ubuntu WSL (ubuntu.com/wsl), Docker WSL2 (docs.docker.com/desktop/wsl), uv (docs.astral.sh/uv).

---

## WSL Commands Reference

Run from a Windows shell (PowerShell/CMD):

```powershell
wsl -l -v                                 # list distributions + state
wsl --set-default Ubuntu-24.04
wsl -d Ubuntu-24.04 [-u root]             # run a distro (optionally as a user)
wsl --terminate Ubuntu-24.04 | --shutdown # stop one | stop all
wsl --install [-d Ubuntu-24.04]           # first-time install
wsl --update ; wsl --version
wsl --export Ubuntu-24.04 D:\backup.tar   # backup
wsl --import Ubuntu-Custom D:\wsl\custom D:\backup.tar ; wsl --set-version Ubuntu-Custom 2
wsl -d Ubuntu-24.04 -e bash -c "echo hi"  # run a single command
```

---

## .wslconfig Reference

Location: `C:\Users\{USERNAME}\.wslconfig` (PowerShell: `"$env:USERPROFILE\.wslconfig"`).
Edit on the Windows side, then `wsl --shutdown` to apply. Core template:

```ini
[wsl2]
memory=16GB        # default: 50% of host RAM or 8GB, whichever is less
processors=8       # default: same as Windows
swap=4GB           # default: 25% of memory
# localhostForwarding, nestedVirtualization, guiApplications, pageReporting default to true

[experimental]
sparseVhd=true               # auto-compact the WSL VHD
autoMemoryReclaim=gradual    # reclaim cached memory (disabled | dropcache | gradual)
# networkingMode=mirrored    # mirror Windows networking
```

---

## Path Mapping & Resource Sizing

| Windows Path | WSL Path | | System RAM | WSL memory | procs | swap |
|--------------|----------|---|-----------|-----------|-------|------|
| `C:\Users\Owner` | `/mnt/c/Users/Owner` | | 16GB | 8GB | 4 | 2GB |
| `D:\projects` | `/mnt/d/projects` | | 32GB | 16GB | 8 | 4GB |
| `N:\Dropbox` | `/mnt/n/Dropbox` | | 64GB | 24GB | 12 | 8GB |
| `\\wsl$\Ubuntu\home\user` | `/home/user` | | 128GB | 48GB | 16 | 16GB |
