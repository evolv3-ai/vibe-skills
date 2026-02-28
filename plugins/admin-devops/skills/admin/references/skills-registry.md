# Skills Registry Management

_Consolidated from `skills/admin (skills registry)` on 2026-02-02_

## Skill Body

# Skill Registry Management

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Requires**: Device profile from `admin` skill

---

## Profile-First Approach

Skills tracked in central registry:

```powershell
# Registry location
$AdminProfile.paths.skillsRegistry
# "C:/Users/Owner/.admin/skills-registry.json"

# Installed skills
$Registry.installedSkills | Format-Table Name, Source, Clients, Status
```

```bash
jq '.installedSkills' "$SKILLS_REGISTRY_PATH"
```

---

## Registry Schema

```json
{
  "schemaVersion": "1.0",
  "clients": { ... },           // Known AI clients
  "skillSources": { ... },      // Marketplaces/repos
  "installedSkills": { ... },   // Per-skill tracking
  "clientInstallations": { ... }, // Per-client summary
  "installMethods": { ... },    // How to install
  "syncHistory": [ ... ]        // Audit trail
}
```

Template: `templates/skills-registry.json`

---

## Quick Reference: Clients

| Client | Install Method | Skills Path | Capabilities |
|--------|---------------|-------------|--------------|
| **Claude Code** | plugin marketplace | `~/.claude/skills/` | skills, commands, agents |
| **Claude Desktop** | manual/MCP | N/A | skills (via MCP) |
| **Cursor** | .cursorrules | `~/.cursor/rules/` | rules only |
| **OpenCode** | symlink | `~/.config/opencode/skills/` | skills |
| **Windsurf** | rules file | `~/.windsurf/` | rules only |
| **Gemini CLI** | AGENTS.md | project root | agents |

---

## List Installed Skills

```powershell
$registry = Get-Content $AdminProfile.paths.skillsRegistry | ConvertFrom-Json

$registry.installedSkills.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Source = $_.Value.source
        Clients = ($_.Value.clients -join ", ")
        Status = $_.Value.status
        Version = $_.Value.version
    }
} | Format-Table
```

```bash
jq -r '.installedSkills | to_entries[] | [.key, .value.source, .value.status] | @tsv' "$SKILLS_REGISTRY_PATH" | column -t
```

---

## Install Skill to Claude Code

### Via Marketplace (Recommended)

```bash
# Add marketplace (one-time)
/plugin marketplace add evolv3-ai/vibe-skills

# Install bundle
/plugin install admin

# Or individual skill
/plugin install ./skills/admin (skills registry)
```

### Update Registry After Install

```powershell
$registry = Get-Content $AdminProfile.paths.skillsRegistry | ConvertFrom-Json

$registry.installedSkills["admin (skills registry)"] = @{
    source = "evolv3-ai/vibe-skills"
    version = "1.0.0"
    installDate = (Get-Date -Format "yyyy-MM-dd")
    installMethod = "plugin"
    bundle = "admin"
    clients = @("claude-code")
    status = "active"
    lastVerified = (Get-Date -Format "yyyy-MM-dd")
    notes = "Skill registry management"
}

$registry.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$registry | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.skillsRegistry
```

---

## Sync Skill to Other Clients

### Export for Cursor/Windsurf

```bash
# Export skill content to rules format
SKILL_PATH="$HOME/.claude/skills/admin (skills registry)"
TARGET="$HOME/.cursor/rules/admin (skills registry).md"

# Copy with header
echo "# admin (skills registry) (from evolv3-ai/vibe-skills)" > "$TARGET"
cat "$SKILL_PATH/SKILL.md" >> "$TARGET"

# Update registry
# Mark as installed on cursor client
```

### Export for Gemini CLI

```bash
# Skills become agents in AGENTS.md format
# Append to project's AGENTS.md
cat >> AGENTS.md << 'EOF'

## admin (skills registry) Agent
Source: evolv3-ai/vibe-skills
Purpose: Skill registry management
EOF
```

---

## Audit Skills

### Check All Installed

```powershell
function Test-SkillsHealth {
    $registry = Get-Content $AdminProfile.paths.skillsRegistry | ConvertFrom-Json

    foreach ($skill in $registry.installedSkills.PSObject.Properties) {
        $name = $skill.Name
        $info = $skill.Value

        # Check if skill files exist
        $skillPath = "$($AdminProfile.paths.claudeSkills)/$name"
        $exists = Test-Path $skillPath

        [PSCustomObject]@{
            Skill = $name
            Source = $info.source
            Status = $info.status
            FilesExist = $exists
            LastVerified = $info.lastVerified
        }
    }
}

Test-SkillsHealth | Format-Table
```

### Verify Against Source

```bash
# Check if local skill matches source version
SKILL="admin (skills registry)"
SOURCE="evolv3-ai/vibe-skills"

# Get source version (from GitHub)
REMOTE_VERSION=$(curl -s "https://raw.githubusercontent.com/$SOURCE/main/skills/$SKILL/SKILL.md" | grep -oP 'version:\s*"\K[^"]+')

# Get local version
LOCAL_VERSION=$(jq -r ".installedSkills[\"$SKILL\"].version" "$SKILLS_REGISTRY_PATH")

echo "Local: $LOCAL_VERSION, Remote: $REMOTE_VERSION"
```

---

## Remove Skill

### From Claude Code

```bash
# Remove symlink or plugin
rm -rf ~/.claude/skills/skill-name

# Or via plugin
/plugin uninstall skill-name
```

### Update Registry

```powershell
$registry = Get-Content $AdminProfile.paths.skillsRegistry | ConvertFrom-Json

# Mark as removed (keep history)
$registry.installedSkills["skill-name"].status = "removed"
$registry.installedSkills["skill-name"].clients = @()

# Or fully remove
$registry.installedSkills.PSObject.Properties.Remove("skill-name")

$registry | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.skillsRegistry
```

---

## Marketplace Management

### List Configured Marketplaces

```powershell
$registry = Get-Content $AdminProfile.paths.skillsRegistry | ConvertFrom-Json
$registry.skillSources | Format-List
```

### Add New Marketplace

```powershell
$registry.skillSources["my-org/skills"] = @{
    type = "marketplace"
    url = "https://github.com/my-org/skills"
    description = "My organization's skills"
    bundles = @("custom")
    default = $false
}

$registry | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.skillsRegistry
```

---

## Sync History

Track all changes:

```powershell
$registry.syncHistory += @{
    date = (Get-Date -Format "yyyy-MM-dd")
    action = "install"
    source = "evolv3-ai/vibe-skills"
    changes = @("Added admin (skills registry) v1.0.0")
}
```

View history:

```bash
jq '.syncHistory | reverse | .[0:10]' "$SKILLS_REGISTRY_PATH"
```

---

## Integration with admin Profile

### Add to Device Profile

```powershell
# Add skills registry path to device profile
$AdminProfile.paths.skillsRegistry = "$($AdminProfile.paths.adminRoot)/skills-registry.json"
$AdminProfile | ConvertTo-Json -Depth 10 | Set-Content $AdminProfile.paths.deviceProfile

# Initialize registry if needed
if (-not (Test-Path $AdminProfile.paths.skillsRegistry)) {
    Copy-Item "templates/skills-registry.json" $AdminProfile.paths.skillsRegistry
}
```

### Cross-Reference with MCP

Skills that provide MCP tools should be tracked in both registries:

```powershell
# If skill adds MCP server, update both
$AdminProfile.mcp.servers["skill-mcp"] = @{ ... }
$registry.installedSkills["skill-mcp-provider"].mcpServer = "skill-mcp"
```

---

## References

- `references/REGISTRY_SCHEMA.md` - Full schema documentation
- `references/CLIENT_COMPATIBILITY.md` - Per-client installation guides
- `references/SYNC_PATTERNS.md` - Multi-client sync strategies

## Scripts

| Script | Purpose |
|--------|---------|
| `skills-update-registry.ps1` | PowerShell registry updater |
| `skills-sync.sh` | Bash multi-client sync |
| `audit-skills.ps1` | Health check all skills |

## Related Skills

| Skill | Purpose |
|-------|---------|
| `admin` | Device profile orchestrator |
| `admin (mcp)` | MCP server management |

## Reference Appendices

### skills: references/CLIENT_COMPATIBILITY.md

# Client Compatibility Guide

How to install skills on different AI coding clients.

---

## Claude Code CLI

**Capabilities**: skills, commands, agents, plugins

### Via Marketplace (Recommended)

```bash
# Add marketplace
/plugin marketplace add evolv3-ai/vibe-skills

# Install bundle
/plugin install admin

# Update
/plugin marketplace update vibe-skills
```

### Via Symlink (Development)

```bash
ln -s ~/dev/vibe-skills/skills/admin (skills registry) ~/.claude/skills/admin (skills registry)
```

### Paths

| Type | Location |
|------|----------|
| Skills | `~/.claude/skills/` |
| Commands | `~/.claude/commands/` |
| Agents | `~/.claude/agents/` |
| Plugins | `~/.claude/plugins/cache/` |

---

## Claude Desktop

**Capabilities**: skills (via MCP or paste)

### Via MCP Server

Skills that provide MCP servers can be used in Claude Desktop:

1. Install MCP server (see `admin (mcp)` skill)
2. Add to `claude_desktop_config.json`
3. Restart Claude Desktop

### Via Manual Paste

For skills without MCP:

1. Copy SKILL.md content
2. Paste into conversation as context
3. Or use Custom Instructions

### Paths

| Type | Location |
|------|----------|
| Config | `%APPDATA%\Claude\claude_desktop_config.json` |

---

## Cursor

**Capabilities**: rules only

### Via .cursorrules

```bash
# Single file approach
cat ~/.claude/skills/admin (skills registry)/SKILL.md >> ~/.cursor/rules/admin (skills registry).md
```

### Via Rules Directory

```bash
# Directory approach (Cursor 0.45+)
mkdir -p ~/.cursor/rules
cp ~/.claude/skills/admin (skills registry)/SKILL.md ~/.cursor/rules/admin (skills registry).md
```

### Paths

| Type | Location |
|------|----------|
| Rules | `~/.cursor/rules/` or project `.cursorrules` |

### Limitations

- No commands support
- No agents support
- Rules loaded per-project
- Must manually update

---

## Windsurf

**Capabilities**: rules only

Similar to Cursor:

```bash
mkdir -p ~/.windsurf
cat ~/.claude/skills/admin (skills registry)/SKILL.md >> ~/.windsurf/admin (skills registry).md
```

### Paths

| Type | Location |
|------|----------|
| Rules | `~/.windsurf/` |

---

## Gemini CLI

**Capabilities**: agents via AGENTS.md

### Via AGENTS.md

Skills become agents in project's AGENTS.md:

```markdown
# AGENTS.md

## admin (skills registry) Agent

**Source**: evolv3-ai/vibe-skills
**Purpose**: Skill registry management across AI clients

### Instructions

[Content from SKILL.md]
```

### Paths

| Type | Location |
|------|----------|
| Agents | Project root `AGENTS.md` |
| Config | `~/.gemini/` |

---

## OpenCode

**Capabilities**: skills

### Via Symlink (Recommended)

```bash
mkdir -p ~/.config/opencode/skills
ln -s ~/dev/vibe-skills/skills/admin (skills registry) ~/.config/opencode/skills/admin (skills registry)
```

### Paths

| Type | Location |
|------|----------|
| Config | `~/.config/opencode/` |
| Skills | `~/.config/opencode/skills/` |

---

## Sync Script Usage

Use `skills-sync.sh` to automate:

```bash
# Sync to Cursor
./scripts/skills-sync.sh sync admin (skills registry) cursor

# Sync to Windsurf
./scripts/skills-sync.sh sync admin (skills registry) windsurf

# List all
./scripts/skills-sync.sh list

# Audit
./scripts/skills-sync.sh audit
```

---

## Feature Comparison

| Feature | Claude Code | Claude Desktop | Cursor | Windsurf | Gemini CLI | OpenCode |
|---------|-------------|----------------|--------|----------|------------|----------|
| Skills | Yes | Via MCP | Rules | Rules | Agents | Yes |
| Commands | Yes | No | No | No | No | No |
| Agents | Yes | No | No | No | Yes | No |
| Plugins | Yes | No | No | No | No | No |
| Auto-update | Yes | No | No | No | No | No |
| Marketplace | Yes | No | No | No | No | No |

### skills: references/REGISTRY_SCHEMA.md

# Skills Registry Schema

Full documentation of the `skills-registry.json` schema.

---

## Top-Level Structure

```json
{
  "schemaVersion": "1.0",
  "lastUpdated": "ISO8601 timestamp",
  "clients": { ... },
  "skillSources": { ... },
  "installedSkills": { ... },
  "clientInstallations": { ... },
  "installMethods": { ... },
  "syncHistory": [ ... ]
}
```

---

## clients

Known AI coding clients and their capabilities.

```json
{
  "claude-code": {
    "name": "Claude Code CLI",
    "configPath": null,
    "skillsPath": "~/.claude/skills",
    "commandsPath": "~/.claude/commands",
    "pluginCachePath": "~/.claude/plugins/cache",
    "installMethod": "plugin-marketplace",
    "capabilities": ["skills", "commands", "agents", "plugins"],
    "notes": "Primary development environment"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable name |
| `configPath` | string? | Config file location |
| `skillsPath` | string? | Where skills are installed |
| `commandsPath` | string? | Where commands are installed |
| `pluginCachePath` | string? | Plugin cache location |
| `installMethod` | string | Default install method |
| `capabilities` | string[] | What the client supports |
| `notes` | string | Additional info |

### Supported Clients

- `claude-code` - Claude Code CLI
- `claude-desktop` - Claude Desktop app
- `cursor` - Cursor IDE
- `windsurf` - Windsurf IDE
- `gemini-cli` - Google Gemini CLI

---

## skillSources

Where skills come from.

```json
{
  "evolv3-ai/vibe-skills": {
    "type": "marketplace",
    "url": "https://github.com/evolv3-ai/vibe-skills",
    "description": "EVOLV3.AI curated skills",
    "bundles": ["admin", "project"],
    "default": true
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | "marketplace", "official", "local" |
| `url` | string? | GitHub URL or null |
| `path` | string? | Local path (for type=local) |
| `description` | string | What this source provides |
| `bundles` | string[] | Available bundles |
| `default` | boolean | Is this the default source |

---

## installedSkills

Per-skill tracking.

```json
{
  "admin": {
    "source": "evolv3-ai/vibe-skills",
    "version": "1.0.0",
    "installDate": "2026-01-15",
    "installMethod": "plugin",
    "bundle": "admin",
    "clients": ["claude-code"],
    "status": "active",
    "lastVerified": "2026-01-20",
    "notes": "Core admin orchestrator",
    "mcpServer": null
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `source` | string | Source identifier |
| `version` | string | Installed version |
| `installDate` | string | When installed (YYYY-MM-DD) |
| `installMethod` | string | How installed |
| `bundle` | string | Parent bundle name |
| `clients` | string[] | Installed on which clients |
| `status` | string | "active", "inactive", "removed", "pending" |
| `lastVerified` | string | Last health check date |
| `notes` | string | Additional info |
| `mcpServer` | string? | Associated MCP server name |

---

## clientInstallations

Summary per client.

```json
{
  "claude-code": {
    "marketplaces": ["evolv3-ai/vibe-skills"],
    "bundles": ["admin", "project"],
    "individualSkills": [],
    "lastSync": "2026-01-20"
  }
}
```

---

## installMethods

How skills can be installed.

```json
{
  "plugin": {
    "description": "Install via Claude Code plugin marketplace",
    "command": "/plugin install {bundle}@{marketplace}",
    "pros": ["Auto-updates", "Bundle management"],
    "cons": ["Requires marketplace setup"]
  }
}
```

### Available Methods

| Method | Best For | Command |
|--------|----------|---------|
| `plugin` | Claude Code | `/plugin install ...` |
| `symlink` | Development | `ln -s ...` |
| `copy` | Any client | `cp -r ...` |
| `rules-file` | Cursor/Windsurf | Append to rules file |

---

## syncHistory

Audit trail of changes.

```json
[
  {
    "date": "2026-01-20",
    "action": "marketplace-update",
    "source": "evolv3-ai/vibe-skills",
    "changes": ["Added admin (skills registry)"]
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `date` | string | When (YYYY-MM-DD) |
| `action` | string | What happened |
| `source` | string | Related source |
| `changes` | string[] | List of changes |

### Action Types

- `install` - New skill installed
- `update` - Skill updated
- `remove` - Skill removed
- `sync` - Synced to another client
- `marketplace-update` - Marketplace refreshed
- `registry-update` - Registry metadata updated
