# Service Management

## Start and Stop

### All Services

```bash
sudo /opt/kasm/current/bin/stop     # Stop everything
sudo /opt/kasm/current/bin/start    # Start everything
```

### Individual Services

```bash
sudo docker restart kasm_api        # API server
sudo docker restart kasm_agent      # Agent
sudo docker restart kasm_manager    # Manager
sudo docker restart kasm_proxy      # Proxy
```

Do NOT restart `kasm_db` unless necessary - it disrupts all services.

---

## Logs

### Live Logs (Follow)

```bash
sudo docker logs -f kasm_api           # API server
sudo docker logs -f kasm_agent         # Agent
sudo docker logs -f kasm_manager       # Manager
sudo docker logs -f kasm_proxy         # Proxy
```

### Last N Lines

```bash
sudo docker logs --tail 50 kasm_api    # Last 50 lines
sudo docker logs --tail 100 kasm_agent # Last 100 lines
```

### Workspace Container Logs

```bash
# Find container ID
sudo docker ps -a | grep -v kasm_

# View logs
sudo docker logs -n 1000 -f <CONTAINER_ID>
```

### File Logs

All logs stored at `/opt/kasm/current/log/` in raw and JSON format.

```bash
ls -la /opt/kasm/current/log/
```

### Filter Errors Only

```bash
sudo docker logs kasm_api 2>&1 | grep -i error | tail -20
sudo docker logs kasm_agent 2>&1 | grep -i error | tail -20
```

---

## Health Checks

### Quick Status

```bash
# All KASM containers running?
sudo docker ps --format "table {{.Names}}\t{{.Status}}" | grep kasm

# Expected output: all containers show "Up" status
```

### System Resources

```bash
# Memory
free -h

# Disk
df -h /var/lib/docker
df -h /mnt/kasm_profiles

# CPU load
uptime

# Docker disk usage
sudo docker system df
```

### Database Connectivity

```bash
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c "SELECT 1;"
```

### Container Count

```bash
# Total KASM infrastructure containers
sudo docker ps | grep "^kasm_" | wc -l

# Active workspace session containers
sudo docker ps | grep -v "^kasm_" | grep -v CONTAINER | wc -l
```

---

## Common Operations

### View All KASM Containers

```bash
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep kasm
```

### Clean Up Docker

```bash
# Remove stopped containers (not KASM infrastructure)
sudo docker container prune -f

# Remove unused volumes
sudo docker volume prune -f

# Remove unused images
sudo docker image prune -f

# Full cleanup (careful - removes unused images too)
sudo docker system prune -f
```

### Check KASM Version

```bash
# From container
sudo docker exec kasm_api cat /usr/local/lib/python3.12/site-packages/api_server/VERSION 2>/dev/null

# Or check the admin UI footer
```

### Restart After System Reboot

KASM should auto-start with Docker. If not:

```bash
sudo /opt/kasm/current/bin/start
```

### Check Docker Daemon

```bash
sudo systemctl status docker
sudo journalctl -u docker --since "1 hour ago"
```
