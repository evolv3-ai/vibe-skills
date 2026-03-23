# Backup & Storage Operations

Database backups, persistent profile management, S3/B2 sync, and restore procedures.

---

## Database Backup

### Quick backup (pg_dump)
```bash
sudo docker exec kasm_db pg_dump -U kasmapp -F t kasm > /tmp/kasm-backup-$(date +%Y%m%d).tar
```

### Official backup script (KASM 1.11+)
```bash
sudo bash /opt/kasm/bin/utils/db_backup -v   --backup-file /tmp/kasm-backup   -q DATABASE_HOSTNAME   --path /opt/kasm/current
```

Add `--exclude-logs` or `-l` to skip log data.

### Config export (via UI)
Admin > Diagnostics > System Info > Import/Export Config. Creates encrypted ZIP with password. Only works between same KASM versions.

---

## Database Restore

### pg_restore
```bash
sudo docker cp backup.tar kasm_db:/tmp/backup.tar
sudo docker exec kasm_db pg_restore -d kasm /tmp/backup.tar -c -U kasmapp
```

### Official restore script
```bash
# Stop all KASM services first
sudo /opt/kasm/current/bin/stop

sudo bash /opt/kasm/current/bin/utils/db_restore   --backup-file /path/to/backup   --database-hostname HOST   --database-user kasmapp   --database-name kasm   --path /opt/kasm/current   --database-master-user MASTER_USER   --database-master-password MASTER_PASS

# Restart after restore
sudo /opt/kasm/current/bin/start
```

---

## S3 / Backblaze B2 Persistent Profiles

### Path format (CRITICAL — include @endpoint)

**WRONG** (causes 8/month in API calls from bucket listing):
```
s3://bucket-name/kasm-profiles/{username}/
```

**CORRECT**:
```
s3://bucket-name@s3.us-west-004.backblazeb2.com/kasm-profiles/{username}/{image_id}/
```

### B2 bucket setup
- Visibility: **Private**
- Lifecycle: **Keep only last version**
- Object Lock: **Disabled**
- App key: must enable **Allow List All Bucket Names**, restrict to single bucket, Read+Write
- Master keys are NOT S3-compatible — must create application key

### KASM S3 config
1. Admin > Settings > Storage
2. Set AWS Access Key ID = B2 Application Key ID
3. Set AWS Secret Access Key = B2 Application Key
4. **Restart API**: `sudo docker restart kasm_api`

### Profile size limits
```json
{
  "environment": {
    "KASM_PROFILE_SIZE_LIMIT": "2000000",
    "KASM_PROFILE_FILTER": ".cache,.vnc,Downloads,Uploads"
  }
}
```

Set via Docker Run Config Override on the workspace.

---

## rclone Backup to B2

### Optimized backup script
```bash
#!/bin/bash
# /opt/kasm-sync/kasm-backup-manager.sh
LOGFILE="/var/log/kasm-backup.log"
LOCKFILE="/tmp/kasm-backup.lock"

# Prevent concurrent syncs
if [ -f "$LOCKFILE" ]; then echo "Backup already running"; exit 0; fi
trap "rm -f $LOCKFILE" EXIT
touch "$LOCKFILE"

rclone sync /mnt/kasm_profiles/ backblaze:kasm-backup/profiles/     --exclude "*.tmp" --exclude "*.cache" --exclude ".vnc/**"     --exclude "Downloads/**" --exclude "Uploads/**"     --bwlimit 50M --log-file="$LOGFILE" --log-level=INFO

rclone sync /mnt/dev_shared/ backblaze:kasm-backup/dev-shared/     --exclude "node_modules/**" --exclude ".git/**" --exclude "*.log"     --exclude "dist/**" --exclude "build/**"     --bwlimit 50M --fast-list --log-file="$LOGFILE" --log-level=INFO
```

### Cron schedule (optimized — 6 syncs/day)
```bash
0 */4 * * * /opt/kasm-sync/kasm-backup-manager.sh
0 6 * * * /opt/kasm-sync/kasm-backup-monitor.sh all
```

### Restore from B2
```bash
rclone sync backblaze:kasm-backup/dev-shared/ /mnt/dev_shared/
rclone sync backblaze:kasm-backup/profiles/ /mnt/kasm_profiles/
```

### Verify backup integrity
```bash
rclone check /mnt/dev_shared/ backblaze:kasm-backup/dev-shared/
```

---

## Profile Directory Management

### Check sizes
```bash
du -sh /mnt/kasm_profiles/*/
du -sh /mnt/kasm_profiles/*/* 2>/dev/null | sort -rh | head -20
```

### Fix permissions (after SFTP upload)
```bash
sudo chown -R 1000:1000 /mnt/kasm_profiles/
sudo find /mnt/kasm_profiles -type d -exec chmod 755 {} \;
sudo find /mnt/kasm_profiles -type f -exec chmod 644 {} \;
```

### Clean stale profiles
```bash
# Find profiles not modified in 30+ days
find /mnt/kasm_profiles -maxdepth 2 -type d -mtime +30

# Delete specific user profile
rm -rf /mnt/kasm_profiles/username/image_id/
```
