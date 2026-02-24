# Common Coolify CLI Workflows

Production-tested multi-step recipes for common automation patterns.

---

## Table of Contents

- [Full Application Deployment Pipeline](#workflow-1-full-application-deployment-pipeline)
- [Environment Variable Management](#workflow-2-environment-variable-management)
- [Database Provisioning with Automated Backups](#workflow-3-database-provisioning-with-automated-backups)
- [Multi-Instance Staging to Production](#workflow-4-multi-instance-staging-to-production)
- [Batch Deployment](#workflow-5-batch-deployment)
- [CI/CD with GitHub Actions](#workflow-6-cicd-with-github-actions)
- [Server Health Check Script](#workflow-7-server-health-check-script)
- [Application Recovery](#workflow-8-application-recovery)
- [SSH Key Setup for New Server](#workflow-9-ssh-key-setup-for-new-server)
- [GitHub App Integration](#workflow-10-github-app-integration)

---

## Workflow 1: Full Application Deployment Pipeline

```bash
# 1. Verify connection
coolify context verify

# 2. Deploy by application name
coolify deploy name my-app --format json

# 3. Monitor deployment status
coolify app deployments list <uuid> --format json | jq '.[0]'

# 4. Check application logs
coolify app logs <uuid> --lines 50

# 5. Verify app is running
coolify app get <uuid> --format json | jq '.status'
```

---

## Workflow 2: Environment Variable Management

### Sync from .env file

```bash
# Export current vars (backup)
coolify app env list <uuid> --format json > current-env-backup.json

# Sync from .env file (creates/updates only, does NOT delete)
coolify app env sync <uuid> --file .env

# Verify sync
coolify app env list <uuid>

# Restart to pick up changes
coolify app restart <uuid>
```

### Individual variable management

```bash
# Create a new variable
coolify app env create <uuid> --key DATABASE_URL --value "postgres://user:pass@host:5432/db"

# Update an existing variable
coolify app env update <uuid> --key DATABASE_URL --value "postgres://user:newpass@host:5432/db"

# Delete a variable
coolify app env delete <uuid> --key OLD_VAR

# Build-time variable (available during build only)
coolify app env create <uuid> --key NODE_ENV --value "production" --is-build
```

---

## Workflow 3: Database Provisioning with Automated Backups

```bash
# 1. Create database
coolify database create --server-uuid <server-uuid> --type postgres --format json

# 2. Get the new database UUID
DB_UUID=$(coolify database list --format json | jq -r '.[-1].uuid')

# 3. Start the database
coolify database start $DB_UUID

# 4. Configure automated daily backup
coolify database backup create $DB_UUID --frequency "daily" --enabled

# 5. Get backup config UUID
BACKUP_UUID=$(coolify database backup list $DB_UUID --format json | jq -r '.[0].uuid')

# 6. Trigger initial backup
coolify database backup trigger $BACKUP_UUID

# 7. Verify backup completed
coolify database backup executions $BACKUP_UUID
```

### With S3 storage

```bash
coolify database backup create $DB_UUID \
  --frequency "0 2 * * *" \
  --enabled \
  --save-s3 \
  --s3-storage-id <storage-id> \
  --retention-days-locally 7
```

---

## Workflow 4: Multi-Instance Staging to Production

```bash
# 1. Set up contexts (one-time)
coolify context add staging https://staging.coolify.example.com <staging-token>
coolify context add production https://prod.coolify.example.com <prod-token>

# 2. Deploy to staging first
coolify deploy name my-app --context staging --format json

# 3. Verify on staging
coolify app logs <uuid> --context staging --lines 50

# 4. Check staging is healthy
coolify app get <uuid> --context staging --format json | jq '.status'

# 5. Deploy to production
coolify deploy name my-app --context production --format json

# 6. Verify production
coolify app logs <uuid> --context production --lines 50
```

---

## Workflow 5: Batch Deployment

Deploy multiple applications simultaneously (e.g., API + worker + frontend).

```bash
# Deploy all at once
coolify deploy batch <api-uuid>,<worker-uuid>,<frontend-uuid> --format json

# Monitor each deployment
coolify deploy list --format json | jq '.[] | {name, status, created_at}'

# Check individual logs if needed
coolify app logs <api-uuid>
coolify app logs <worker-uuid>
coolify app logs <frontend-uuid>
```

---

## Workflow 6: CI/CD with GitHub Actions

### Basic deployment on push to main

```yaml
name: Deploy to Coolify
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Install Coolify CLI
        run: curl -fsSL https://raw.githubusercontent.com/coollabsio/coolify-cli/main/scripts/install.sh | bash

      - name: Deploy
        run: |
          coolify context add production "$COOLIFY_URL" "$COOLIFY_TOKEN"
          coolify deploy name my-app --context production --format json
        env:
          COOLIFY_URL: ${{ secrets.COOLIFY_URL }}
          COOLIFY_TOKEN: ${{ secrets.COOLIFY_TOKEN }}
```

### With staging verification

```yaml
name: Deploy Pipeline
on:
  push:
    branches: [main]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - name: Install Coolify CLI
        run: curl -fsSL https://raw.githubusercontent.com/coollabsio/coolify-cli/main/scripts/install.sh | bash

      - name: Deploy to Staging
        run: |
          coolify context add staging "$STAGING_URL" "$STAGING_TOKEN"
          coolify deploy name my-app --context staging --format json
        env:
          STAGING_URL: ${{ secrets.COOLIFY_STAGING_URL }}
          STAGING_TOKEN: ${{ secrets.COOLIFY_STAGING_TOKEN }}

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    steps:
      - name: Install Coolify CLI
        run: curl -fsSL https://raw.githubusercontent.com/coollabsio/coolify-cli/main/scripts/install.sh | bash

      - name: Deploy to Production
        run: |
          coolify context add production "$PROD_URL" "$PROD_TOKEN"
          coolify deploy name my-app --context production --format json
        env:
          PROD_URL: ${{ secrets.COOLIFY_PROD_URL }}
          PROD_TOKEN: ${{ secrets.COOLIFY_PROD_TOKEN }}
```

---

## Workflow 7: Server Health Check Script

```bash
#!/bin/bash
# check-servers.sh - Validate all servers in current context

echo "Checking servers..."
coolify server list --format json | jq -r '.[].uuid' | while read uuid; do
  NAME=$(coolify server get "$uuid" --format json | jq -r '.name')
  echo -n "  $NAME ($uuid): "
  if coolify server validate "$uuid" > /dev/null 2>&1; then
    echo "OK"
  else
    echo "FAILED"
  fi
done
```

### Multi-context health check

```bash
#!/bin/bash
# check-all-contexts.sh - Verify all contexts are reachable

for ctx in $(coolify context list --format json | jq -r '.[].name'); do
  echo -n "Context '$ctx': "
  if coolify context verify --context "$ctx" > /dev/null 2>&1; then
    echo "OK"
  else
    echo "UNREACHABLE"
  fi
done
```

---

## Workflow 8: Application Recovery

```bash
# 1. Stop misbehaving app
coolify app stop <uuid>

# 2. Check recent deployments for what changed
coolify app deployments list <uuid> --format json | jq '.[0:3]'

# 3. View deployment logs for the failing deploy
coolify app deployments logs <deployment-uuid>

# 4. Restart (without rebuild)
coolify app restart <uuid>

# 5. Monitor logs for recovery
coolify app logs <uuid> --follow

# 6. If still failing, redeploy
coolify deploy uuid <uuid>
```

---

## Workflow 9: SSH Key Setup for New Server

```bash
# 1. Add SSH key (must be passwordless)
coolify private-key add --name "deploy-key" --file ~/.ssh/id_ed25519

# 2. Get key UUID
KEY_UUID=$(coolify private-key list --format json | jq -r '.[-1].uuid')

# 3. Add server with the key
coolify server add \
  --name "web-1" \
  --ip 192.168.1.100 \
  --private-key-uuid $KEY_UUID \
  --user root

# 4. Validate server connectivity
SERVER_UUID=$(coolify server list --format json | jq -r '.[-1].uuid')
coolify server validate $SERVER_UUID

# 5. Verify server appears
coolify server list
```

---

## Workflow 10: GitHub App Integration

```bash
# 1. List existing GitHub Apps
coolify github list --format json

# 2. Create new GitHub App integration
coolify github create \
  --name "my-deploy-app" \
  --app-id 123456 \
  --private-key-uuid <key-uuid> \
  --webhook-secret "my-webhook-secret"

# 3. Get the app ID
APP_ID=$(coolify github list --format json | jq -r '.[-1].id')

# 4. List accessible repos
coolify github repos $APP_ID --format json

# 5. List branches for a specific repo
coolify github branches $APP_ID --repo my-org/my-repo

# 6. Use this GitHub App when creating applications
# (Reference the GitHub App ID in app create)
```

---

## Tips for Scripting

### Extract UUIDs for automation

```bash
# Get all app UUIDs
coolify app list --format json | jq -r '.[].uuid'

# Get UUID by app name
coolify app list --format json | jq -r '.[] | select(.name=="my-app") | .uuid'

# Get first server UUID
coolify server list --format json | jq -r '.[0].uuid'
```

### Error handling in scripts

```bash
#!/bin/bash
set -euo pipefail

# Verify context before any operations
if ! coolify context verify > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to Coolify instance"
  exit 1
fi

# Deploy with error checking
if coolify deploy name my-app --format json; then
  echo "Deployment triggered successfully"
else
  echo "Deployment failed"
  exit 1
fi
```
