# Multi-Agent Bot Deployment Patterns

Patterns for deploying multiple AI bot agents on KASM Workspaces.

---

## Architecture Options

### Pattern A: Shared Backend, Multiple Frontends

One gateway instance, all channels share conversation memory.

```
Host:
  /opt/gateway/
  ├── config.json (shared)
  └── sessions/    (shared across all channels)

KASM sessions are access windows only — no per-agent isolation.
```

**Best for**: Single operator, multi-channel (same bot on Telegram + Discord + Mattermost).
**RAM**: ~4 GB total.

### Pattern B: Isolated Agents, Shared Knowledge (Recommended)

Each KASM workspace runs its own bot agent. Private conversations per agent. Shared volume for inter-agent communication.

```
/mnt/kasm_profiles/
├── admin/
│   ├── {hermes-alpha-image-id}/   # Agent Alpha's persistent state
│   │   └── .hermes-alpha/
│   └── {hermes-beta-image-id}/    # Agent Beta's persistent state
│       └── .hermes-beta/

/mnt/hermes_shared/                # Shared volume (all agents)
├── knowledge/
├── handoffs/
└── logs/
```

**Best for**: Multiple specialized agents, each with own personality/config.
**RAM**: ~4 GB per agent.

### Pattern C: Agent Swarm — Specialized Bots

Dedicated agents per function (research-bot, code-bot, ops-bot). Structured inbox/bus for inter-agent coordination.

```
/mnt/kasm_profiles/
├── research-bot/
├── code-bot/
├── ops-bot/

/opt/swarm/
├── inbox/         # Inter-agent message queue
├── knowledge/     # Shared knowledge base
└── state/         # Agent registry JSON
```

**Best for**: Specialized bot teams, high complexity.
**RAM**: ~4 GB per agent.

---

## Implementation: Pattern B (One Workspace Per Agent)

### Step 1: Create profile directory on server

```bash
ssh root@$SERVER "mkdir -p /mnt/kasm_profiles && chown -R 1000:1000 /mnt/kasm_profiles"
```

### Step 2: Create shared volume (optional)

```bash
ssh root@$SERVER "mkdir -p /mnt/hermes_shared && chown -R 1000:1000 /mnt/hermes_shared"
```

### Step 3: Clone workspace per agent

```bash
# Clone Debian Bullseye workspace for each agent
for AGENT in alpha beta gamma; do
  sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
    INSERT INTO images (
      image_id, friendly_name, name, image_type, cores, memory, enabled,
      persistent_profile_path, docker_exec_config, volume_mappings
    )
    SELECT
      gen_random_uuid(),
      'Hermes ${AGENT^}',
      name, image_type, cores, memory, true,
      persistent_profile_path,
      docker_exec_config,
      volume_mappings
    FROM images
    WHERE friendly_name = 'Debian Bullseye'
    RETURNING image_id, friendly_name;
  "
done
```

### Step 4: Set per-agent environment variables

```bash
# Set Docker Run Config Override for each agent
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET docker_run_config_override = '{
    "environment": {
      "HERMES_AGENT_NAME": "alpha",
      "HERMES_HOME": "/home/kasm-user/.hermes-alpha"
    }
  }'
  WHERE friendly_name = 'Hermes Alpha';
"
```

### Step 5: Add shared volume mapping

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
  WHERE friendly_name LIKE 'Hermes%';
"
```

### Step 6: Add Docker Exec Config (sudo)

```bash
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE images
  SET docker_exec_config = '{"first_launch":{"user":"root","cmd":"bash -c \\"bash -c 'echo \"kasm-user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/kasm-user && chmod 440 /etc/sudoers.d/kasm-user'\\""}}'
  WHERE friendly_name LIKE 'Hermes%';
"
```

### Step 7: Assign to group and restart API

```bash
# Assign all Hermes workspaces to All Users group
sudo docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO image_group_settings (image_id, group_id)
  SELECT i.image_id, g.group_id
  FROM images i, groups g
  WHERE i.friendly_name LIKE 'Hermes%' AND g.name = 'All Users'
  ON CONFLICT DO NOTHING;
"

sudo docker restart kasm_api
```

---

## Agent Registry Pattern

Track agents with a JSON file on the shared volume:

```json
{
  "hermes-alpha": {"status": "online", "channel": "mattermost", "model": "openrouter/sonnet"},
  "hermes-beta":  {"status": "online", "channel": "telegram",   "model": "openrouter/gpt-4o"},
  "hermes-gamma": {"status": "idle",   "channel": "discord",    "model": "openrouter/opus"}
}
```

Agents read/write this from `/home/kasm-user/shared/registry.json`.
