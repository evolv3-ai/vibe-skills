# Workspace Management

CRUD operations for KASM workspaces (called "Images" in the API).

---

## List All Workspaces

### Via API
```bash
curl -k -X POST "https://$KASM_HOST/api/public/get_images"   -H "Content-Type: application/json"   -d '{"api_key":"$KEY","api_key_secret":"$SECRET"}'
```

### Via DB (more detail)
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "SELECT image_id, friendly_name, name, cores, memory, enabled, persistent_profile_path FROM images ORDER BY friendly_name;"
```

---

## Create a Workspace

### Via API
```bash
curl -k -X POST "https://$KASM_HOST/api/admin/create_image"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "target_image": {
      "friendly_name": "My Workspace",
      "name": "kasmweb/core-debian-bullseye:1.18.0",
      "image_type": "Container",
      "cores": 2,
      "memory": 2768000000,
      "enabled": true,
      "persistent_profile_path": "/mnt/kasm_profiles/{username}/{image_id}"
    }
  }'
```

### Via DB (direct insert)

Use when the API doesn't expose all fields (e.g., Docker Exec Config):

```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO images (image_id, friendly_name, name, image_type, cores, memory, enabled, persistent_profile_path)
  VALUES (gen_random_uuid(), 'My Workspace', 'kasmweb/core-debian-bullseye:1.18.0', 'Container', 2, 2768000000, true, '/mnt/kasm_profiles/{username}/{image_id}')
  RETURNING image_id, friendly_name;
"
```

---

## Clone a Workspace

KASM has no native clone API. Two approaches:

### Approach 1: DB Clone (recommended)

```bash
# Get source workspace details
sudo docker exec kasm_db psql -U kasmapp -d kasm -t -c   "SELECT row_to_json(i) FROM images i WHERE friendly_name = 'Debian Bullseye';"

# Insert clone with new name and ID
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO images (
    image_id, friendly_name, name, image_type, cores, memory, enabled,
    persistent_profile_path, docker_exec_config, docker_run_config_override,
    volume_mappings, description
  )
  SELECT
    gen_random_uuid(), 'Hermes Alpha', name, image_type, cores, memory, enabled,
    persistent_profile_path, docker_exec_config, docker_run_config_override,
    volume_mappings, description
  FROM images
  WHERE friendly_name = 'Debian Bullseye'
  RETURNING image_id, friendly_name;
"
```

### Approach 2: API Create + Copy Settings

Read source via API, then create new image with same settings but different name/env vars.

---

## Update a Workspace

### Via API
```bash
curl -k -X POST "https://$KASM_HOST/api/admin/update_image"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "target_image": {
      "image_id": "<UUID>",
      "friendly_name": "Updated Name",
      "cores": 4,
      "memory": 4096000000
    }
  }'
```

### Via DB (for fields not in API)
```bash
# Update Docker Exec Config
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET docker_exec_config = '{"first_launch":{"user":"root","cmd":"bash -c \\"bash -c 'echo \"kasm-user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/kasm-user && chmod 440 /etc/sudoers.d/kasm-user'\\""}}'
  WHERE image_id = '<UUID>';
"

# Update Docker Run Config Override
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET docker_run_config_override = '{"hostname":"hermes-alpha","environment":{"HERMES_AGENT_NAME":"alpha","HERMES_HOME":"/home/kasm-user/.hermes-alpha"}}'
  WHERE image_id = '<UUID>';
"

# Enable persistent profiles
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET persistent_profile_path = '/mnt/kasm_profiles/{username}/{image_id}'
  WHERE image_id = '<UUID>';
"
```

**Always restart kasm_api after DB changes:**
```bash
sudo docker restart kasm_api
```

---

## Delete a Workspace

### Via API
```bash
curl -k -X POST "https://$KASM_HOST/api/admin/delete_image"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "target_image": {
      "image_id": "<UUID>"
    }
  }'
```

### Via DB
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "DELETE FROM images WHERE image_id = '<UUID>' RETURNING friendly_name;"
```

---

## Assign Workspace to Group

```bash
# Find group ID
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "SELECT group_id, name FROM groups;"

# Assign workspace to group
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO image_group_settings (image_id, group_id)
  VALUES ('<IMAGE_UUID>', '<GROUP_UUID>')
  ON CONFLICT DO NOTHING;
"
```
