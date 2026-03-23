# User & Group Management

Manage KASM users, groups, and permissions via API and DB.

---

## List Users

### Via API
```bash
curl -k -X POST "https://$KASM_HOST/api/admin/get_users"   -H "Content-Type: application/json"   -d '{"api_key":"$KEY","api_key_secret":"$SECRET"}'
```

### Via DB
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT user_id, username, locked, last_session FROM users ORDER BY username;
"
```

---

## Create User

### Via API
```bash
curl -k -X POST "https://$KASM_HOST/api/admin/create_user"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "target_user": {
      "username": "botuser",
      "password": "<SECURE_PASSWORD>",
      "first_name": "Bot",
      "last_name": "User",
      "locked": false,
      "disabled": false
    }
  }'
```

---

## Update User

```bash
curl -k -X POST "https://$KASM_HOST/api/admin/update_user"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "target_user": {
      "user_id": "<UUID>",
      "locked": false
    }
  }'
```

---

## Delete User

```bash
curl -k -X POST "https://$KASM_HOST/api/admin/delete_user"   -H "Content-Type: application/json"   -d '{
    "api_key": "$KEY",
    "api_key_secret": "$SECRET",
    "target_user": {
      "user_id": "<UUID>"
    }
  }'
```

---

## Groups

### List Groups
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c   "SELECT group_id, name FROM groups ORDER BY name;"
```

### Add User to Group
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO group_membership (user_id, group_id)
  VALUES ('<USER_UUID>', '<GROUP_UUID>')
  ON CONFLICT DO NOTHING;
"
```

### Remove User from Group
```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  DELETE FROM group_membership
  WHERE user_id = '<USER_UUID>' AND group_id = '<GROUP_UUID>';
"
```

### Group Settings (Persistent Profiles)
```bash
# Check if persistent profiles are enabled for a group
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT gs.group_id, g.name, gs.name as setting, gs.value
  FROM group_settings gs
  JOIN groups g ON gs.group_id = g.group_id
  WHERE gs.name = 'allow_persistent_profile';
"

# Enable persistent profiles for a group
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO group_settings (group_id, name, value)
  VALUES ('<GROUP_UUID>', 'allow_persistent_profile', 'True')
  ON CONFLICT (group_id, name) DO UPDATE SET value = 'True';
"
```
