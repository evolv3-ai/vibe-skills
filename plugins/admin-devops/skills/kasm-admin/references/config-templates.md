# Config Templates

Copy-paste-ready JSON configs for KASM workspace settings.

---

## Docker Exec Config (first_launch)

### Sudo only
```json
{
  "first_launch": {
    "user": "root",
    "cmd": "bash -c \"bash -c 'echo \"kasm-user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/kasm-user && chmod 440 /etc/sudoers.d/kasm-user'\""
  }
}
```

### Sudo + D-Bus + Keyring (for VS Code / MCP tools)
```json
{
  "first_launch": {
    "user": "root",
    "cmd": "bash -c \"bash -c 'echo \"kasm-user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/kasm-user && chmod 440 /etc/sudoers.d/kasm-user' && mkdir -p /run/user/1000 && chmod 700 /run/user/1000 && chown 1000:1000 /run/user/1000 && dbus-daemon --session --address=unix:path=/run/user/1000/bus --nofork --nopidfile --syslog-only &\""
  }
}
```

### Full kitchen sink (sudo + keyring + packages)
```json
{
  "first_launch": {
    "user": "root",
    "cmd": "bash -c \"apt-get update && apt-get install -y sudo gnome-keyring libsecret-1-0 dbus-x11 && bash -c 'echo \"kasm-user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/kasm-user && chmod 440 /etc/sudoers.d/kasm-user' && mkdir -p /home/kasm-user/.local/share/keyrings && unset DBUS_SESSION_BUS_ADDRESS && eval \\\"$(dbus-launch --sh-syntax)\\\" && eval \\\"$(/usr/bin/gnome-keyring-daemon --start --components=secrets)\\\" && /usr/bin/desktop_ready\""
  }
}
```

**Important**: Only ONE `first_launch` block is allowed. Chain commands with `&&`.
**Important**: Use `>> /etc/sudoers` not `/etc/sudoers.d/` — many base images lack the includedir directive.

---

## Docker Run Config Override

### Basic (hostname + resolution)
```json
{
  "hostname": "kasm",
  "shm_size": "512m",
  "environment": {
    "KASMVNC_DESKTOP_ALLOW_RESIZE": "false",
    "KASMVNC_DESKTOP_RESOLUTION_WIDTH": "1920",
    "KASMVNC_DESKTOP_RESOLUTION_HEIGHT": "1080"
  }
}
```

### Bot agent with custom env vars
```json
{
  "hostname": "hermes-alpha",
  "shm_size": "512m",
  "environment": {
    "HERMES_AGENT_NAME": "alpha",
    "HERMES_HOME": "/home/kasm-user/.hermes-alpha"
  }
}
```

### Docker-in-Docker (privileged)
```json
{
  "privileged": true,
  "shm_size": "1g"
}
```

### Disable PulseAudio + D-Bus env
```json
{
  "environment": {
    "START_PULSEAUDIO": "0",
    "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"
  }
}
```

---

## Volume Mappings

### Shared development volume
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

### Inter-agent shared volume
```json
{
  "/mnt/hermes_shared": {
    "bind": "/home/kasm-user/shared",
    "mode": "rw",
    "uid": 1000,
    "gid": 1000,
    "required": false,
    "skip_check": false
  }
}
```

### Multiple mounts
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

---

## Persistent Profile Path

```
/mnt/kasm_profiles/{username}/{image_id}
```

Available variables: `{username}`, `{user_id}`, `{image_id}`

Server prep:
```bash
sudo mkdir -p /mnt/kasm_profiles
sudo chown -R 1000:1000 /mnt/kasm_profiles
```
