# Resource Monitoring & Capacity Planning

Monitor server resources, plan workspace density, and prevent overcommit.

---

## Server-Level Health

### Via sentinelctl (recommended for fleet)
```bash
sentinelctl pull --config fleet.json --token $TOKEN --connection-mode direct
```

Returns JSON with: `cpu_percent`, `memory_used_percent`, `disk_used_percent`, `container_total`, `container_running`, `container_healthy`.

### Via SSH
```bash
# System overview
ssh root@$SERVER "free -h && echo '---' && df -h / && echo '---' && uptime"

# Docker resource usage (all containers)
ssh root@$SERVER "docker stats --no-stream"

# KASM session containers only
ssh root@$SERVER "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' | grep -v kasm_"
```

---

## Capacity Formula

```
KASM overhead:           ~1 GB RAM (see breakdown below)
Per-session overhead:    ~200 MB (VNC, audio, upload/download services)
Per-workspace allocation: configured in workspace settings (cores, memory)

Max sessions = (Total RAM - 1GB overhead) / Per-session RAM

Example: 32 GB server, 4 GB per bot workspace:
(32 - 1) / 4 = 7 concurrent bot sessions
```

---

## Resource Sizing Guide

| Workspace Type | Cores | Memory | Notes |
|----------------|-------|--------|-------|
| Browser-only | 1 | 1 GB | Minimal, browsing only |
| Light development | 2 | 2 GB | Text editing, light CLI |
| Full desktop | 2 | 2.7 GB | KASM default |
| Heavy development | 4 | 4 GB | Docker-in-Docker, builds |
| AI Bot (Hermes/OpenClaw) | 2-4 | 4 GB | Gateway + LLM API calls |
| GPU workloads | 2-4 | 4+ GB | Requires GPU passthrough |

---

## CPU Allocation Methods

| Method | Docker Flag | Behavior |
|--------|-------------|----------|
| Shares (default) | `--cpu-shares` | Can burst above limit when server is idle. Only throttled during contention. |
| Quotas | `--cpus` | Hard ceiling, never exceeds. Consistent but no bursting. |

**Recommendation**: Use Shares for bot workspaces (they spike during LLM processing, then idle).

---

## Per-Workspace Resource Audit

```bash
# What's allocated vs what's available
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT
    SUM(CASE WHEN enabled THEN cores ELSE 0 END) as total_cores_allocated,
    SUM(CASE WHEN enabled THEN memory/1000000000.0 ELSE 0 END)::numeric(10,1) as total_gb_allocated,
    COUNT(*) FILTER (WHERE enabled) as enabled_workspaces
  FROM images;
"

# Compare with server capacity
ssh root@$SERVER "nproc && free -h | grep Mem"
```

**Note**: Allocated != in-use. KASM only consumes resources for active sessions, not all enabled workspaces.

---

## Disk Usage

```bash
# Docker disk usage
ssh root@$SERVER "docker system df"

# Persistent profile sizes
ssh root@$SERVER "du -sh /mnt/kasm_profiles/*"

# Largest profile directories
ssh root@$SERVER "du -sh /mnt/kasm_profiles/*/* 2>/dev/null | sort -rh | head -20"
```

---

## Alerts / Thresholds

Integrate with sentinelctl CI gate mode:

```bash
# Fails if any server is offline or has unhealthy containers
sentinelctl pull --config fleet.json --token $TOKEN --connection-mode direct --ci

# Check specific app container
sentinelctl pull --config fleet.json --token $TOKEN --connection-mode direct --ci --container-match kasm
```

Recommended alert thresholds:
- CPU > 70%: warning
- CPU > 90%: critical
- RAM > 70%: warning
- RAM > 90%: critical
- Disk > 70%: warning (especially profile directories)
- Disk > 90%: critical

---

## KASM Service Memory Breakdown (Idle Baseline)

| Container | Memory |
|-----------|--------|
| kasm_db | 277 MB |
| kasm_api | 247 MB |
| kasm_manager | 200 MB |
| kasm_guac | 79 MB |
| kasm_rdp_gateway | 44 MB |
| kasm_agent | 43 MB |
| kasm_share | 25 MB |
| kasm_proxy | 13 MB |
| kasm_rdp_https_gateway | 11 MB |
| kasm_redis | <1 MB |
| **Total** | **~960 MB** |

---

## "No Agent Slots" False Positive

This error can appear even when resources are plentiful. Common causes:

1. **Stale cached application state** — restart services to clear:
   ```bash
   sudo docker restart kasm_api kasm_agent kasm_manager
   ```

2. **Orphaned user containers** consuming slots:
   ```bash
   sudo docker ps -a | grep kasm_user_
   sudo docker rm -f $(sudo docker ps -aq --filter "name=kasm_user_")
   ```

3. **Stale manager hostname in DB** (after IP/hostname change):
   ```bash
   sudo docker exec kasm_db psql -U kasmapp -d kasm -c      "UPDATE managers SET manager_hostname='$(hostname)' WHERE manager_hostname != '$(hostname)';"
   sudo /opt/kasm/current/bin/stop && sudo /opt/kasm/current/bin/start
   ```

4. **Storage provider validation failure** (e.g., broken Dropbox provider):
   Disable the broken provider in Admin > Settings > Storage, then restart API.

**Always verify actual resources** before believing the error:
```bash
free -h && docker stats --no-stream
```
