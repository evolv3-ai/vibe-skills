# Bulk Operations

Batch updates across multiple KASM workspaces via DB queries.

---

## Bulk Update Docker Exec Config

Apply the same Docker Exec Config to multiple workspaces at once.

### Add sudo to ALL workspaces
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET docker_exec_config = '{"first_launch":{"user":"root","cmd":"bash -c \\"bash -c 'echo \"kasm-user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/kasm-user && chmod 440 /etc/sudoers.d/kasm-user'\\""}}'
  WHERE enabled = true
  RETURNING friendly_name;
"
sudo docker restart kasm_api
```

### Add sudo + dbus/keyring to ALL workspaces
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET docker_exec_config = '{"first_launch":{"user":"root","cmd":"bash -c \\"bash -c 'echo \"kasm-user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/kasm-user && chmod 440 /etc/sudoers.d/kasm-user' && mkdir -p /run/user/1000 && chmod 700 /run/user/1000 && chown 1000:1000 /run/user/1000 && dbus-daemon --session --address=unix:path=/run/user/1000/bus --nofork --nopidfile --syslog-only &\\""}}'
  WHERE enabled = true
  RETURNING friendly_name;
"
sudo docker restart kasm_api
```

### Update only specific workspaces (by name pattern)
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET docker_exec_config = '<CONFIG_JSON>'
  WHERE friendly_name LIKE 'Hermes%'
  RETURNING friendly_name;
"
```

---

## Bulk Update Resources

### Set all bot workspaces to 4 cores / 4GB
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET cores = 4, memory = 4096000000
  WHERE friendly_name LIKE 'Hermes%' OR friendly_name LIKE 'OpenClaw%'
  RETURNING friendly_name, cores, memory;
"
sudo docker restart kasm_api
```

---

## Bulk Enable Persistent Profiles

```bash
# Enable on all workspaces that don't have it set
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET persistent_profile_path = '/mnt/kasm_profiles/{username}/{image_id}'
  WHERE persistent_profile_path IS NULL OR persistent_profile_path = ''
  RETURNING friendly_name;
"
sudo docker restart kasm_api
```

---

## Bulk Add Volume Mappings

### Add shared volume to all bot workspaces
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET volume_mappings = '{
    \"/mnt/hermes_shared\": {
      \"bind\": \"/home/kasm-user/shared\",
      \"mode\": \"rw\",
      \"uid\": 1000,
      \"gid\": 1000,
      \"required\": false,
      \"skip_check\": false
    }
  }'
  WHERE friendly_name LIKE 'Hermes%'
  RETURNING friendly_name;
"
sudo docker restart kasm_api
```

---

## Bulk Enable/Disable Workspaces

```bash
# Disable all OpenClaw workspaces (migrating to Hermes)
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images SET enabled = false
  WHERE friendly_name LIKE 'OpenClaw%'
  RETURNING friendly_name, enabled;
"
sudo docker restart kasm_api
```

---

## Audit: List All Workspace Configs

```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT friendly_name, cores, memory/1000000 as memory_mb,
         CASE WHEN persistent_profile_path IS NOT NULL AND persistent_profile_path != '' THEN 'yes' ELSE 'no' END as profiles,
         CASE WHEN docker_exec_config IS NOT NULL AND docker_exec_config != '' THEN 'yes' ELSE 'no' END as exec_config,
         CASE WHEN volume_mappings IS NOT NULL AND volume_mappings != '' THEN 'yes' ELSE 'no' END as volumes,
         enabled
  FROM images
  ORDER BY friendly_name;
"
```
