# Known Issues with Coolify CLI

Detailed documentation of known bugs, limitations, and workarounds.

**Source**: https://github.com/coollabsio/coolify-cli/issues
**Last Reviewed**: 2026-02-22

---

## Table of Contents

- [Bug #1: "cannot unmarshal array" on env sync](#bug-1-cannot-unmarshal-array-on-env-sync)
- [Bug #2: service env update returns 404](#bug-2-service-env-update-returns-404)
- [Bug #3: Table rendering issues](#bug-3-table-rendering-issues)
- [Limitation #1: No database restore command](#limitation-1-no-database-restore-command)
- [Limitation #2: No persistent storage management](#limitation-2-no-persistent-storage-management)
- [Limitation #3: Env sync is one-directional](#limitation-3-env-sync-is-one-directional)
- [Limitation #4: No passphrase-protected SSH keys](#limitation-4-no-passphrase-protected-ssh-keys)

---

## Bug #1: "cannot unmarshal array" on env sync

**Error**: `cannot unmarshal array into Go value of type ...`
**Command**: `coolify app env sync <uuid> --file .env`
**Source**: https://github.com/coollabsio/coolify-cli/issues/49
**Status**: Open (as of 2026-02-22)

### When it happens

When the `.env` file or existing environment variables contain array-like values, or when the API response format doesn't match the expected schema for bulk operations.

### Workaround

**Option A**: Sync variables individually:
```bash
while IFS='=' read -r key value; do
  [ -z "$key" ] || [[ "$key" == \#* ]] && continue
  coolify app env create <uuid> --key "$key" --value "$value"
done < .env
```

**Option B**: Ensure `.env` file uses only simple `KEY=VALUE` format:
```env
# Good - simple values
DATABASE_URL=postgres://user:pass@host:5432/db
API_KEY=sk-1234567890

# Bad - may cause issues
ALLOWED_ORIGINS=["http://localhost","https://example.com"]
```

---

## Bug #2: service env update returns 404

**Error**: HTTP 404 Not Found
**Command**: `coolify service env update <uuid> --key <key> --value <value>`
**Source**: https://github.com/coollabsio/coolify-cli/issues/48
**Status**: Open (as of 2026-02-22)

### Root cause

The CLI calls the wrong API endpoint for service environment variable updates. The endpoint used for applications doesn't match the service-specific API.

### Workaround

Delete and recreate the variable:
```bash
coolify service env delete <uuid> --key MY_KEY
coolify service env create <uuid> --key MY_KEY --value "new_value"
```

### Note

This only affects **service** env updates. Application env updates (`coolify app env update`) work correctly.

---

## Bug #3: Table rendering issues

**Error**: Misaligned columns, truncated content, or broken formatting in table output
**Command**: Any command with default table output containing wide content
**Source**: https://github.com/coollabsio/coolify-cli/issues/54
**Status**: Open (as of 2026-02-22)

### When it happens

When table cells contain long strings (URLs, UUIDs, descriptions), the table formatter can produce misaligned or truncated output, especially in narrow terminals.

### Workaround

Use JSON output for reliable data:
```bash
# Instead of default table
coolify app list

# Use JSON
coolify app list --format json

# Or pretty-printed JSON
coolify app list --format pretty

# Pipe to jq for formatted table-like output
coolify app list --format json | jq -r '.[] | "\(.name)\t\(.uuid)\t\(.status)"'
```

---

## Limitation #1: No database restore command

**Source**: https://github.com/coollabsio/coolify-cli/issues/44
**Status**: Feature request (open)

### Impact

The CLI can trigger backups and view backup executions, but cannot restore from a backup. Restore operations must be performed through the Coolify web dashboard.

### Workaround

1. Use the Coolify web UI to restore from backups
2. For automated restore, use the Coolify REST API directly:
```bash
# Check the API docs for restore endpoints
# https://coolify.io/docs/api-reference/introduction
```

---

## Limitation #2: No persistent storage management

**Source**: https://github.com/coollabsio/coolify-cli/issues/57
**Status**: Feature request (open)

### Impact

Cannot attach, detach, or manage persistent storage volumes for applications via the CLI. Storage configuration must be done through the web dashboard.

### Workaround

Configure storage mounts through the Coolify web dashboard before or after deploying via CLI.

---

## Limitation #3: Env sync is one-directional

**Not a bug** - this is by design, but frequently misunderstood.

### Behavior

`coolify app env sync <uuid> --file .env` performs a **one-directional merge**:
- Variables in `.env` that don't exist in Coolify: **Created**
- Variables in `.env` that already exist in Coolify: **Updated**
- Variables in Coolify that aren't in `.env`: **Preserved** (NOT deleted)

### Why this matters

Over time, Coolify can accumulate stale variables that have been removed from your `.env` file. The env list in Coolify may drift from your local file.

### Workaround

To achieve full sync (making Coolify match `.env` exactly):

```bash
# 1. List current Coolify vars
coolify app env list <uuid> --format json | jq -r '.[].key' > coolify-keys.txt

# 2. List .env keys
grep -v '^#' .env | grep '=' | cut -d'=' -f1 > env-keys.txt

# 3. Find keys to delete (in Coolify but not in .env)
comm -23 <(sort coolify-keys.txt) <(sort env-keys.txt) | while read key; do
  echo "Deleting: $key"
  coolify app env delete <uuid> --key "$key"
done

# 4. Sync remaining
coolify app env sync <uuid> --file .env

# Cleanup
rm coolify-keys.txt env-keys.txt
```

---

## Limitation #4: No passphrase-protected SSH keys

### Impact

SSH keys added via `coolify private-key add` must be passwordless. Keys with passphrases are not supported.

### Workaround

Generate a dedicated passwordless key for Coolify:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/coolify_deploy -N ""
coolify private-key add --name "coolify-deploy" --file ~/.ssh/coolify_deploy
```

---

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 401 Unauthorized | Expired/rotated token | `coolify context set-token <name> <new-token>` |
| Connection refused | Wrong URL or server down | Check URL in `coolify context get` |
| "context not found" | Typo in context name | `coolify context list` to see names |
| Config file not found (Windows) | Missing directory | Create `%USERPROFILE%\.config\coolify\` |
| Table output garbled | Wide content overflow | Use `--format json` or `--format pretty` |
| Deploy hangs | Network issue or large build | Check with `--debug` flag |
| "cannot unmarshal array" | Complex env values | Use individual `env create` instead |
| 404 on service env | Known CLI bug #48 | Delete + recreate variable |
