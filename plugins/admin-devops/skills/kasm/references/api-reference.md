# KASM API Reference

## Authentication

KASM API uses **JSON payload authentication** (NOT HTTP Basic Auth).

Every request must include `api_key` and `api_key_secret` in the JSON body.

### Get API Credentials

1. Log into KASM Admin UI
2. Go to Settings > Developer API Keys
3. Create or copy existing API key and secret

### Request Format

All requests are **POST** with JSON body:

```bash
curl -k -X POST "https://<SERVER_IP>/api/public/<ENDPOINT>" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<YOUR_API_KEY>",
    "api_key_secret": "<YOUR_API_KEY_SECRET>"
  }'
```

The `-k` flag ignores the self-signed certificate. Remove it if using proper HTTPS.

---

## Important Terminology

The KASM API uses different names than the UI:

| UI Term | API Term |
|---------|----------|
| Workspaces | Images |
| Storage Mappings | Storage Providers |
| Servers | Servers (same) |
| Users | Users (same) |

---

## Common Endpoints

### List Workspaces (Images)

```bash
curl -k -X POST "https://<SERVER_IP>/api/public/get_images" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<KEY>",
    "api_key_secret": "<SECRET>"
  }'
```

### Get System Info

```bash
curl -k -X POST "https://<SERVER_IP>/api/admin/system_info" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<KEY>",
    "api_key_secret": "<SECRET>"
  }'
```

### Update a Workspace (Image)

```bash
curl -k -X POST "https://<SERVER_IP>/api/admin/update_image" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<KEY>",
    "api_key_secret": "<SECRET>",
    "target_image": {
      "image_id": "<IMAGE_UUID>",
      "friendly_name": "Updated Name",
      "cores": 2,
      "memory": 2768000000
    }
  }'
```

### Create Storage Provider

```bash
curl -k -X POST "https://<SERVER_IP>/api/admin/create_storage_provider" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<KEY>",
    "api_key_secret": "<SECRET>",
    "target_storage_provider": {
      "storage_provider_type": "nextcloud",
      "enabled": true,
      "nextcloud_url": "https://nextcloud.example.com"
    }
  }'
```

### List Storage Providers

```bash
curl -k -X POST "https://<SERVER_IP>/api/admin/get_storage_providers" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<KEY>",
    "api_key_secret": "<SECRET>"
  }'
```

### Create User Session

```bash
curl -k -X POST "https://<SERVER_IP>/api/public/request_kasm" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<KEY>",
    "api_key_secret": "<SECRET>",
    "user_id": "<USER_UUID>",
    "image_id": "<IMAGE_UUID>"
  }'
```

### Destroy Session

```bash
curl -k -X POST "https://<SERVER_IP>/api/public/destroy_kasm" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "<KEY>",
    "api_key_secret": "<SECRET>",
    "kasm_id": "<SESSION_UUID>"
  }'
```

---

## API Endpoint Categories

### Public Endpoints (`/api/public/`)

Available with standard API keys:
- `get_images` - List available workspaces
- `request_kasm` - Create a new session
- `destroy_kasm` - End a session
- `get_kasms` - List active sessions

### Admin Endpoints (`/api/admin/`)

Require admin API key:
- `system_info` - System status and health
- `update_image` - Modify workspace settings
- `create_storage_provider` - Add storage
- `get_storage_providers` - List storage
- `get_users` - List all users
- `create_user` - Add a user
- `update_user` - Modify user

---

## Error Handling

API errors return JSON with error details:

```json
{
  "error_message": "Description of the error",
  "status": "error"
}
```

Common error codes:
- **401**: Invalid API key/secret
- **403**: Insufficient permissions (need admin key for admin endpoints)
- **404**: Resource not found (wrong image_id, user_id, etc.)
- **500**: Server error (check `sudo docker logs kasm_api`)
