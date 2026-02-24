---
name: kasm
description: |
  Manage KASM Workspaces - a container-based VDI platform streaming desktops to browsers.
  Covers installation, workspace configuration, persistent profiles, S3 storage, backup/recovery,
  troubleshooting, and API operations for single-server and multi-server deployments.

  Use when: installing KASM, configuring workspaces, setting up persistent profiles, troubleshooting
  "No Resources Available", container destruction errors, backup to Backblaze B2, Cloudflare Tunnel setup,
  database operations, or managing KASM services.
license: MIT
---

# KASM Workspaces

**Purpose**: Install, configure, manage, and troubleshoot KASM Workspaces on Linux servers.

## Step 0: Determine What the User Needs

Ask the user which task they need help with:

| Task | Reference |
|------|-----------|
| Fresh installation | `references/installation.md` |
| Workspace configuration (profiles, volumes, Docker overrides) | `references/workspace-configuration.md` |
| Troubleshooting errors | `references/troubleshooting.md` |
| Backup and recovery | `references/backup-recovery.md` |
| Cloudflare Tunnel or reverse proxy | `references/networking.md` |
| Database queries or maintenance | `references/database-operations.md` |
| API calls or automation | `references/api-reference.md` |
| Service management (start/stop/logs) | `references/service-management.md` |

Read the appropriate reference file and follow its instructions.

---

## Quick Reference

### System Requirements
- Docker >= 25.0.5, Docker Compose >= 2.40.2
- Minimum: 2 cores, 4GB RAM, 75GB SSD
- Per session default: 2,768MB RAM + 2 cores
- Swap partition strongly recommended
- Supported: Ubuntu 22.04/24.04, Debian 11/12, RHEL 8/9/10, Oracle Linux 8/9, AlmaLinux/Rocky 8/9, Raspberry Pi OS 11/12
- Architectures: amd64 and arm64

### Key Paths
| Path | Purpose |
|------|---------|
| `/opt/kasm/current/` | Installation root |
| `/opt/kasm/current/bin/start` | Start all services |
| `/opt/kasm/current/bin/stop` | Stop all services |
| `/opt/kasm/current/log/` | Log files (raw + JSON) |
| `/mnt/kasm_profiles/` | Persistent profiles (volume mount) |
| `/var/lib/docker` | Docker storage |

### Key Containers
| Container | Role |
|-----------|------|
| `kasm_api` | API server |
| `kasm_agent` | Agent (runs workspace containers) |
| `kasm_manager` | Manager (orchestration) |
| `kasm_proxy` | HTTPS proxy |
| `kasm_db` | PostgreSQL database (user: kasmapp, db: kasm) |

### Service Control
```bash
sudo /opt/kasm/current/bin/stop     # Stop all
sudo /opt/kasm/current/bin/start    # Start all
sudo docker restart kasm_api        # Restart single service
sudo docker logs -f kasm_api        # Live logs
```

---

## Critical Rules

- Always install Docker CE + Compose plugin BEFORE KASM.
- Always configure swap - KASM can be unstable without it even with sufficient RAM.
- Each concurrent session needs ~2-4GB RAM. Size the server accordingly.
- Do not expose port 8443 publicly without HTTPS.
- KASM API uses JSON payload auth (NOT HTTP Basic Auth). See `references/api-reference.md`.
- The API calls workspaces "images" - `get_images` not `get_workspaces`.
- For S3 persistent profiles, always include `@endpoint` in the path. Missing it causes excessive API calls.

## Related Skills

- `devops` for server inventory and provisioning
- `backblaze-b2` for S3-compatible storage
- Provider skills (oci, hetzner, contabo, etc.) for server setup
- `cloudflare-worker-base` for Cloudflare integrations

## References

- KASM docs: https://kasmweb.com/docs/latest/
- KASM new docs: https://docs.kasm.com/
- KASM GitHub issues: https://github.com/kasmtech/workspaces-issues
- KASM Docker images: https://github.com/kasmtech
