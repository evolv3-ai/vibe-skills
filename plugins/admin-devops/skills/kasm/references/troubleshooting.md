# Troubleshooting

Production-tested playbooks for common KASM issues.

---

## "No Resources Available" Error

The most common KASM error. Multiple possible root causes.

### Check 1: Are Resources Actually Exhausted?

```bash
# Check RAM
free -h

# Check disk
df -h /var/lib/docker

# Check running containers
sudo docker ps | wc -l
```

If resources are fine, the error is likely from stale state.

### Check 2: Stale Hostname in Database

This happens when the server hostname changes (common after reboots on some VPS providers).

```bash
# Check current hostname
hostname

# Check what KASM thinks the hostname is
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "SELECT manager_id, manager_hostname FROM managers;"

# Fix if mismatched
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "UPDATE managers SET manager_hostname='$(hostname)' WHERE manager_hostname != '$(hostname)';"

# Restart services
sudo /opt/kasm/current/bin/stop
sudo /opt/kasm/current/bin/start
```

### Check 3: Cached Application State

Sometimes services cache stale data about available resources.

```bash
sudo docker restart kasm_api kasm_agent kasm_manager
```

If that doesn't work, full restart:

```bash
sudo /opt/kasm/current/bin/stop
sudo /opt/kasm/current/bin/start
```

---

## Container Destruction Failures (Zombie Containers)

**Symptom**: `docker.errors.APIError: 500 Server Error... "cannot remove container"... "could not kill: tried to kill container, but did not receive an exit event"`

### Fix

```bash
# Stop KASM
sudo /opt/kasm/current/bin/stop

# Find and force-remove stuck containers
sudo docker ps -a | grep -v "kasm_" | grep -v "CONTAINER"
sudo docker rm -f <STUCK_CONTAINER_ID>

# Clean up orphaned volumes
sudo docker volume prune -f

# Restart Docker daemon
sudo systemctl restart docker

# Start KASM
sudo /opt/kasm/current/bin/start
```

### Nuclear Option (Emergency)

If multiple zombie containers:

```bash
sudo /opt/kasm/current/bin/stop

# Remove ALL non-KASM containers
sudo docker ps -a --format '{{.Names}}' | grep -v "^kasm_" | xargs -r sudo docker rm -f

# Clean everything
sudo docker volume prune -f
sudo docker network prune -f

sudo systemctl restart docker
sudo /opt/kasm/current/bin/start
```

---

## Base64 / binascii Errors

**Symptom**: `binascii.Error` in `api_server/utils.py`, CherryPy stack trace with base64 padding errors.

**Root cause**: Corrupt or stale session tokens in the database.

### Fix

```bash
# Clean expired session tokens
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM session_tokens WHERE expiration < NOW();"

# Restart API
sudo docker restart kasm_api
```

---

## Session Token StaleDataError

**Symptom**: `StaleDataError: UPDATE statement on table 'session_tokens' expected to update 1 row(s); 0 were matched`

**Root cause**: Race condition with session token updates, usually after service disruption.

### Fix

```bash
# Clean all expired tokens
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM session_tokens WHERE expiration < NOW();"

# If problem persists, clean ALL tokens (will log out all users)
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "TRUNCATE session_tokens;"

# Restart API
sudo docker restart kasm_api
```

---

## File Manager Not Opening (Jammy Containers)

**Symptom**: File manager app doesn't open or crashes immediately in Ubuntu Jammy-based workspaces.

### Diagnostic Sequence

1. **Test from terminal inside the container**:
   ```bash
   # Try different file managers
   nautilus &
   thunar &
   pcmanfm &
   ```

2. **Check X11 display**:
   ```bash
   echo $DISPLAY
   xrandr
   ```

3. **Check for PulseAudio conflicts**: Add to workspace Docker Run Config Override:
   ```json
   {"environment": {"START_PULSEAUDIO": "0"}}
   ```

4. **Verify user permissions**: Container should run as uid 1000

5. **Check for zombie containers**: Previous session may have left stuck containers (see above)

6. **Fresh session**: Stop workspace, delete session, launch new session

---

## VS Code / Keyring Errors

**Symptom**: GNOME keyring missing errors, VS Code settings not persisting, MCP tools failing with keyring errors.

### Fix: Add D-Bus + Keyring Setup

Add this to workspace Docker Exec Config:

```json
{
  "first_launch": {
    "user": "root",
    "cmd": "bash -c 'mkdir -p /run/user/1000 && chmod 700 /run/user/1000 && chown 1000:1000 /run/user/1000 && dbus-daemon --session --address=unix:path=/run/user/1000/bus --nofork --nopidfile --syslog-only &'"
  }
}
```

Also add to Docker Run Config Override:
```json
{
  "environment": {
    "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"
  }
}
```

### VS Code Settings Location

Settings persist if persistent profiles are configured:
- User settings: `~/.config/Code/User/settings.json`
- Extensions: `~/.vscode/extensions/`
- Workspace settings: `.vscode/settings.json`

---

## File Permission Issues (After SFTP Upload)

**Symptom**: Files uploaded via SFTP have wrong ownership, causing permission denied errors in containers.

### Fix

```bash
# Fix profile permissions
sudo chown -R 1000:1000 /mnt/kasm_profiles/
sudo chmod -R 755 /mnt/kasm_profiles/

# Fix shared storage permissions
sudo chown -R 1000:1000 /mnt/dev_shared/
sudo chmod -R 755 /mnt/dev_shared/
```

### Prevention

Configure SFTP client to:
1. Connect as user with uid 1000 (not root)
2. Set default upload permissions: 644 for files, 755 for directories

---

## Storage Provider Validation Errors

**Symptom**: False "No Agent slots" errors caused by storage provider (Dropbox, Nextcloud) validation failures.

### Fix

```bash
# Restart services to clear cached validation state
sudo docker restart kasm_api kasm_agent kasm_manager

# If persists, check storage provider config in admin UI:
# Infrastructure > Storage Providers
# Remove any broken providers

# Verify storage mappings
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "SELECT * FROM storage_providers;"
```

---

## Persistent Profile Data Loss

**Known issue**: GitHub issue #622 reports small files can be lost with S3-mounted profiles.

### Mitigation

1. Use volume mount profiles instead of S3 for critical data
2. Configure `KASM_PROFILE_FILTER` to exclude non-essential files
3. Set up independent backup of `/mnt/kasm_profiles/` (see `backup-recovery.md`)
4. Keep profile size limits reasonable (`KASM_PROFILE_SIZE_LIMIT`)

---

## General Diagnostic Commands

```bash
# All KASM container status
sudo docker ps | grep kasm

# API health
sudo docker logs --tail 50 kasm_api | grep -i error

# Agent health
sudo docker logs --tail 50 kasm_agent | grep -i error

# Manager health
sudo docker logs --tail 50 kasm_manager | grep -i error

# Database connectivity
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c "SELECT 1;"

# System resources
free -h
df -h
uptime

# Docker disk usage
sudo docker system df

# List all containers (including stopped)
sudo docker ps -a
```
