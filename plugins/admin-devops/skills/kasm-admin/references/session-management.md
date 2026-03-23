# Session Management

Monitor and manage active KASM sessions (called "Kasms" in the API).

---

## List Active Sessions

### Via API
```bash
curl -k -X POST "https://$KASM_HOST/api/admin/get_kasms"   -H "Content-Type: application/json"   -d '{"api_key":"$KEY","api_key_secret":"$SECRET"}'
```

### Via DB
```bash
# All running sessions with user and workspace info
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT k.kasm_id, u.username, i.friendly_name, k.start_date,
         k.operational_status, k.container_id
  FROM kasms k
  JOIN images i ON k.image_id = i.image_id
  JOIN users u ON k.user_id = u.user_id
  WHERE k.operational_status = 'running'
  ORDER BY k.start_date DESC;
"

# Session count per workspace
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT i.friendly_name, COUNT(k.kasm_id) as active_sessions
  FROM kasms k
  JOIN images i ON k.image_id = i.image_id
  WHERE k.operational_status = 'running'
  GROUP BY i.friendly_name
  ORDER BY active_sessions DESC;
"
```

### Via Docker (container-level view)
```bash
# List all KASM session containers
sudo docker ps --filter 'label=com.kasmweb.image' --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'

# Resource usage per container
sudo docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' | grep -v kasm_
```

---

## Create a Session (Launch Workspace)

```bash
curl -k -X POST "https://$KASM_HOST/api/public/request_kasm"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "user_id": "<USER_UUID>",
    "image_id": "<IMAGE_UUID>"
  }'
```

Response includes `kasm_id` and connection URL.

---

## Destroy a Session

```bash
curl -k -X POST "https://$KASM_HOST/api/public/destroy_kasm"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "kasm_id": "<SESSION_UUID>"
  }'
```

---

## Kill All Sessions (Emergency)

```bash
# Get all active session IDs
sudo docker exec kasm_db psql -U kasmapp -d kasm -t -c   "SELECT kasm_id FROM kasms WHERE operational_status = 'running';"

# Or force-kill via Docker (nuclear option)
sudo docker ps --filter 'label=com.kasmweb.image' -q | xargs -r sudo docker rm -f

# Clean up DB state
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "UPDATE kasms SET operational_status = 'stopped' WHERE operational_status = 'running';"

sudo docker restart kasm_api kasm_agent kasm_manager
```

---

## Session History

```bash
# Recent sessions (last 24h)
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT u.username, i.friendly_name, k.start_date, k.expiration_date, k.operational_status
  FROM kasms k
  JOIN images i ON k.image_id = i.image_id
  JOIN users u ON k.user_id = u.user_id
  WHERE k.start_date > NOW() - INTERVAL '24 hours'
  ORDER BY k.start_date DESC;
"
```
