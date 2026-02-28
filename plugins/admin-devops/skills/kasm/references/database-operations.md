# Database Operations

KASM uses PostgreSQL running in the `kasm_db` Docker container.

## Connection

```bash
# Interactive psql session
sudo docker exec -it kasm_db psql -U kasmapp -d kasm

# Run a single query
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c "SELECT 1;"
```

**Database details**:
- Container: `kasm_db`
- User: `kasmapp`
- Database: `kasm`
- Port: 5432 (internal to Docker network)
- Image: `kasmweb/postgres:X.XX.X`

---

## Common Queries

### List Workspaces (Images)

```sql
SELECT image_id, friendly_name, enabled, cores, memory
FROM images
ORDER BY friendly_name;
```

### Check Managers

```sql
SELECT manager_id, manager_hostname, zone_id
FROM managers;
```

### Check Agents

```sql
SELECT server_id, hostname, zone_id, enabled
FROM servers;
```

### Check Storage Providers

```sql
SELECT storage_provider_id, storage_provider_type, enabled
FROM storage_providers;
```

### List Users

```sql
SELECT user_id, username, realm, locked, disabled
FROM users;
```

### Active Sessions

```sql
SELECT session_id, user_id, start_date, status
FROM sessions
WHERE status = 'running';
```

---

## Maintenance Operations

### Clean Expired Session Tokens

Fixes base64/binascii errors and StaleDataError.

```sql
DELETE FROM session_tokens WHERE expiration < NOW();
```

### Fix Hostname Mismatch

Fixes "No Resources Available" when hostname changed.

```bash
# Check current vs stored hostname
hostname
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "SELECT manager_hostname FROM managers;"

# Update to current hostname
sudo docker exec -it kasm_db psql -U kasmapp -d kasm -c \
  "UPDATE managers SET manager_hostname='$(hostname)';"
```

### Truncate All Session Tokens (Nuclear)

Logs out all users. Use when token corruption is widespread.

```sql
TRUNCATE session_tokens;
```

### Check Database Size

```sql
SELECT pg_size_pretty(pg_database_size('kasm'));
```

### Check Table Sizes

```sql
SELECT relname AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;
```

---

## Backup & Restore

### Backup

```bash
# Custom format (recommended - supports selective restore)
sudo docker exec kasm_db pg_dump -U kasmapp -Fc kasm > kasm_backup.dump

# Plain SQL (human-readable)
sudo docker exec kasm_db pg_dump -U kasmapp kasm > kasm_backup.sql
```

### Restore

```bash
# Stop KASM first
sudo /opt/kasm/current/bin/stop

# Restore from custom format
sudo docker exec -i kasm_db pg_restore -U kasmapp -d kasm -c < kasm_backup.dump

# Or restore from SQL
sudo docker exec -i kasm_db psql -U kasmapp -d kasm < kasm_backup.sql

# Start KASM
sudo /opt/kasm/current/bin/start
```

---

## Safety Notes

- Always back up the database before running UPDATE or DELETE queries
- Use transactions for multi-step operations: `BEGIN; ... COMMIT;` (or `ROLLBACK;`)
- The database is the single source of truth for all KASM configuration
- Restarting `kasm_db` will interrupt ALL KASM services
