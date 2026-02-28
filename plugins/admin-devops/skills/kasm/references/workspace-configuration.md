# Workspace Configuration

## Persistent Profiles

Persistent profiles save user data between sessions. Two methods available.

### Method 1: Volume Mount (Recommended for Single Server)

Set in workspace settings or group settings:

**Path format**: `/mnt/kasm_profiles/{username}/{image_id}`

Available variables:
- `{username}` - User's login name
- `{user_id}` - User's UUID
- `{image_id}` - Workspace image UUID

**Server setup**:
```bash
sudo mkdir -p /mnt/kasm_profiles
sudo chown -R 1000:1000 /mnt/kasm_profiles
```

**Group setting**: Access Management > Groups > Edit > `allow_persistent_profile` = true

### Method 2: S3 Storage (Multi-Server or Cloud Backup)

**Path format**: `s3://bucket-name@s3.region.backblazeb2.com/path/{username}/`

**CRITICAL**: Always include `@endpoint` in the path. Without it, KASM performs bucket listing on every profile operation, which caused $68 in API charges from 16M calls.

**Wrong**: `s3://my-bucket/kasm-profiles/{username}/`
**Correct**: `s3://my-bucket@s3.us-west-004.backblazeb2.com/kasm-profiles/{username}/`

**Server Settings** (Admin UI > Server Settings):
- Set AWS Access Key ID
- Set AWS Secret Access Key
- Restart KASM API after changing credentials: `sudo docker restart kasm_api`

**Requirements**:
- V4 signatures only
- IAM permissions: read/write bucket + presigned URLs

### Profile Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `KASM_PROFILE_SIZE_LIMIT` | Size limit in KB | `2000000` (2GB) |
| `KASM_PROFILE_FILTER` | Excluded paths (comma-separated) | `.cache,.vnc,Downloads,Uploads` |

### User Launch Options

When launching a workspace, users can choose:
- **Enabled**: Load existing profile
- **Disabled**: No profile (temporary session)
- **Reset**: Delete existing profile and start fresh

### Multi-Server Persistent Profiles

Requires shared storage accessible from all Agent hosts:
- NFS, HDFS, GFS, SMB, or SSHFS
- Same mount path on every Agent

---

## Volume Mappings

Volume mappings mount host directories into workspace containers.

### JSON Format

Set in workspace settings under "Volume Mappings":

```json
{
  "/host/path": {
    "bind": "/container/path",
    "mode": "rw",
    "uid": 1000,
    "gid": 1000,
    "required": true,
    "skip_check": false
  }
}
```

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `bind` | string | Path inside the container |
| `mode` | string | `rw` (read-write) or `ro` (read-only) |
| `uid` | int | User ID for ownership (1000 = kasm-user) |
| `gid` | int | Group ID for ownership |
| `required` | bool | Fail session if mount unavailable |
| `skip_check` | bool | Skip existence check on host |

### Example: Shared Development Workspace

```json
{
  "/mnt/dev_shared": {
    "bind": "/home/kasm-user/dv",
    "mode": "rw",
    "uid": 1000,
    "gid": 1000,
    "required": true,
    "skip_check": false
  }
}
```

**Server setup**:
```bash
sudo mkdir -p /mnt/dev_shared
sudo chown -R 1000:1000 /mnt/dev_shared

# Create folder structure
sudo -u "#1000" mkdir -p /mnt/dev_shared/projects
sudo -u "#1000" mkdir -p /mnt/dev_shared/resources
sudo -u "#1000" mkdir -p /mnt/dev_shared/tools
```

### Example: Multiple Mounts

```json
{
  "/mnt/dev_shared": {
    "bind": "/home/kasm-user/dv",
    "mode": "rw",
    "uid": 1000,
    "gid": 1000,
    "required": true,
    "skip_check": false
  },
  "/mnt/readonly_docs": {
    "bind": "/home/kasm-user/docs",
    "mode": "ro",
    "uid": 1000,
    "gid": 1000,
    "required": false,
    "skip_check": false
  }
}
```

### Setting Volume Mappings

Can be set at two levels:
1. **Workspace level**: Workspaces > Edit workspace > Volume Mappings
2. **Group level**: Access Management > Groups > Edit group > Volume Mappings

Group-level mappings apply to all workspaces accessed by that group.

---

## Docker Run Config Override

Override Docker container settings for workspaces.

### Common Overrides

```json
{
  "hostname": "dev-workspace",
  "privileged": false,
  "shm_size": "512m",
  "environment": {
    "START_PULSEAUDIO": "0",
    "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"
  }
}
```

**Fields**:
| Field | Purpose | Default |
|-------|---------|---------|
| `hostname` | Container hostname | Random |
| `privileged` | Privileged mode (use cautiously) | false |
| `shm_size` | Shared memory size | 512m |
| `environment` | Environment variables | {} |

### Disable PulseAudio (Fix Audio Issues)

```json
{"environment": {"START_PULSEAUDIO": "0"}}
```

### Increase Shared Memory (For Chrome-Heavy Workloads)

```json
{"shm_size": "2g"}
```

---

## Docker Exec Config

Run commands when a container first launches.

### Fix GNOME Keyring / VS Code Issues

VS Code and MCP tools in KASM containers need D-Bus and gnome-keyring. Without this, you get keyring errors and settings loss.

```json
{
  "first_launch": {
    "user": "root",
    "cmd": "bash -c 'mkdir -p /run/user/1000 && chmod 700 /run/user/1000 && chown 1000:1000 /run/user/1000 && dbus-daemon --session --address=unix:path=/run/user/1000/bus --nofork --nopidfile --syslog-only &'"
  }
}
```

Set in workspace settings under "Docker Exec Config (JSON)".

---

## Resource Configuration

### Per-Workspace Resources

Set in workspace settings:
- **Cores**: Number of CPU cores (default: 2)
- **Memory**: RAM in MB (default: 2768)
- **GPU Count**: GPUs allocated (default: 0)

### Sizing Guide

| Use Case | Cores | Memory |
|----------|-------|--------|
| Browser-only | 1 | 1024 MB |
| Light development | 2 | 2048 MB |
| Full desktop (default) | 2 | 2768 MB |
| Heavy development | 4 | 4096 MB |
| GPU workloads | 2-4 | 4096+ MB |

### Server Capacity Planning

```
Max concurrent sessions = (Total RAM - 4GB KASM overhead) / Per-session RAM

Example: 8GB server with 2768MB per session:
(8192 - 4096) / 2768 = ~1.5 sessions (practically 1 concurrent session)

Example: 32GB server:
(32768 - 4096) / 2768 = ~10 concurrent sessions
```
