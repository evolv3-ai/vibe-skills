# Backup & Recovery

## Backup Methods

### 1. Configuration Export (Admin UI)

Export all KASM configuration as JSON via the admin interface.

**Steps**:
1. Log in as admin
2. Navigate to Diagnostics > Export
3. Download the JSON export file
4. Store securely

**Restores**: Workspaces, groups, users, settings, storage providers
**Does NOT restore**: User session data, persistent profiles, database state

### 2. Database Backup (pg_dump)

Full PostgreSQL backup of the KASM database.

```bash
# Create backup
sudo docker exec kasm_db pg_dump -U kasmapp -Fc kasm > kasm_backup_$(date +%Y%m%d).dump

# Verify backup file
ls -lh kasm_backup_*.dump
```

### 3. Built-in Backup Script (1.11.0+)

```bash
sudo /opt/kasm/current/bin/utils/db_backup
```

### 4. Profile Directory Backup

```bash
# Simple tar backup
sudo tar -czf kasm_profiles_$(date +%Y%m%d).tar.gz /mnt/kasm_profiles/
```

---

## Recovery

### Database Restore

```bash
# Stop KASM services
sudo /opt/kasm/current/bin/stop

# Restore database
sudo docker exec -i kasm_db pg_restore -U kasmapp -d kasm -c < kasm_backup_YYYYMMDD.dump

# Start services
sudo /opt/kasm/current/bin/start
```

### Configuration Import

1. Log in as admin
2. Navigate to Diagnostics > Import
3. Upload the JSON export file
4. Review and confirm changes

---

## S3 Backup (Backblaze B2)

Production-tested backup to S3-compatible storage using rclone.

### Setup rclone

```bash
# Install rclone
sudo apt install -y rclone

# Configure remote
rclone config
# Choose: New remote
# Name: backblaze
# Type: s3
# Provider: Backblaze B2 (or Other)
# Access Key ID: <your-key>
# Secret Access Key: <your-secret>
# Endpoint: s3.us-west-004.backblazeb2.com (or your region)
```

### Sync Profiles to B2

```bash
rclone sync /mnt/kasm_profiles/ backblaze:your-bucket/profiles/ \
  --exclude "*.tmp" \
  --exclude "*.cache" \
  --exclude ".vnc/**" \
  --exclude "Downloads/**" \
  --exclude "Uploads/**" \
  --exclude "node_modules/**" \
  --exclude ".git/**" \
  --exclude "build/**" \
  --exclude "dist/**" \
  --bwlimit 50M \
  --log-file /var/log/kasm-backup.log \
  --log-level INFO
```

### Sync Shared Storage to B2

```bash
rclone sync /mnt/dev_shared/ backblaze:your-bucket/dev-shared/ \
  --exclude "node_modules/**" \
  --exclude ".git/**" \
  --exclude "build/**" \
  --exclude "dist/**" \
  --bwlimit 50M
```

### Automated Backup (Cron)

```bash
# Edit crontab
sudo crontab -e

# Run every 4 hours
0 */4 * * * /opt/kasm-sync/sync-to-s3.sh >> /var/log/kasm-backup.log 2>&1

# Daily monitoring report at 6 AM
0 6 * * * /opt/kasm-sync/kasm-backup-monitor.sh report >> /var/log/kasm-backup-report.txt 2>&1
```

### Backup Script Template

Create `/opt/kasm-sync/sync-to-s3.sh`:

```bash
#!/bin/bash
LOCKFILE="/tmp/kasm-sync.lock"
LOGFILE="/var/log/kasm-backup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Prevent concurrent runs
if [ -f "$LOCKFILE" ]; then
    echo "[$DATE] Sync already running, skipping" >> $LOGFILE
    exit 0
fi

trap "rm -f $LOCKFILE" EXIT
touch "$LOCKFILE"

echo "[$DATE] Starting KASM backup sync" >> $LOGFILE

# Sync profiles
rclone sync /mnt/kasm_profiles/ backblaze:your-bucket/profiles/ \
    --exclude "*.tmp" --exclude ".cache/**" --exclude ".vnc/**" \
    --exclude "Downloads/**" --exclude "Uploads/**" \
    --bwlimit 50M >> $LOGFILE 2>&1

# Sync shared storage
rclone sync /mnt/dev_shared/ backblaze:your-bucket/dev-shared/ \
    --exclude "node_modules/**" --exclude ".git/**" \
    --bwlimit 50M >> $LOGFILE 2>&1

# Database backup
sudo docker exec kasm_db pg_dump -U kasmapp -Fc kasm > /tmp/kasm_db_latest.dump 2>> $LOGFILE
rclone copy /tmp/kasm_db_latest.dump backblaze:your-bucket/db-backups/ >> $LOGFILE 2>&1

echo "[$DATE] Backup sync completed" >> $LOGFILE
```

```bash
sudo chmod +x /opt/kasm-sync/sync-to-s3.sh
```

---

## Backblaze B2 Gotchas

### Missing @endpoint in S3 Path

If using B2 for persistent profiles (not backup), the S3 path MUST include `@endpoint`:

**Wrong**: `s3://my-bucket/profiles/{username}/`
**Correct**: `s3://my-bucket@s3.us-west-004.backblazeb2.com/profiles/{username}/`

Without `@endpoint`, KASM performs bucket listing on every profile operation. This caused 16M API calls and a $68 bill in production.

### Optimizing API Calls

- Use lock files to prevent concurrent syncs
- Limit to 6 syncs/day instead of continuous
- Use `--bwlimit` to prevent bandwidth saturation
- Exclude large/unnecessary files (node_modules, .git, cache)

### Monitoring Backup Health

```bash
# Check last backup
tail -20 /var/log/kasm-backup.log

# Check backup size on B2
rclone size backblaze:your-bucket/

# Verify a specific file exists
rclone ls backblaze:your-bucket/profiles/ | head
```
